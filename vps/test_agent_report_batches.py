import importlib.util
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest import mock
from urllib.error import URLError


AGENT_PATH = Path(__file__).with_name("agent.py")
VPS_IP = "203.0.113.9"


class FakeResponse:
    def __init__(self, data):
        self.data = data

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_value, traceback):
        return False

    def read(self):
        return json.dumps(self.data).encode("utf-8")


class FakeRealtime:
    connected = True
    enabled = True
    last_disconnected = 0

    def __init__(self):
        self.messages = []

    def send(self, data, message_type="status"):
        self.messages.append((data, message_type))
        return True


def load_agent(workdir, name):
    config_path = Path(workdir) / "config.json"
    state_path = Path(workdir) / "traffic-state.json"
    config_path.write_text(json.dumps({
        "api_url": "https://panel.example.test/api/config",
        "report_url": "https://panel.example.test/api/report",
        "ip": VPS_IP,
        "token": "test-token",
    }), encoding="utf-8")
    spec = importlib.util.spec_from_file_location(name, AGENT_PATH)
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    with mock.patch.dict(os.environ, {
        "KUI_AGENT_CONFIG_FILE": str(config_path),
        "KUI_TRAFFIC_STATE_PATH": str(state_path),
    }, clear=False):
        spec.loader.exec_module(module)
    return module, state_path


def nodes(count):
    return [
        {"id": f"node{index:03d}", "port": 10000 + index, "protocol": "VLESS"}
        for index in range(count)
    ]


def configure_reporting(agent, bytes_by_node):
    agent.get_system_status = lambda interval: {"cpu": 1, "mem": 2}
    agent.get_port_traffic = lambda port, protocol, node_id: bytes_by_node[node_id]
    agent.realtime_channel = None
    agent.last_http_report = 0
    agent.global_interval = 5
    agent.fast_mode = False
    agent.dynamic_ping = {"ct": None, "cu": None, "cm": None}


def post_recorder(requests, outcomes):
    def urlopen(request, timeout):
        requests.append(json.loads(request.data.decode("utf-8")))
        outcome = outcomes.pop(0)
        if isinstance(outcome, Exception):
            raise outcome
        return FakeResponse(outcome)
    return urlopen


class AgentReportBatchTests(unittest.TestCase):
    def test_splits_more_than_200_entries_into_unique_persisted_reports(self):
        with tempfile.TemporaryDirectory() as workdir:
            agent, state_path = load_agent(workdir, "agent_report_split")
            current_nodes = nodes(401)
            bytes_by_node = {node["id"]: 100 for node in current_nodes}
            agent.last_reported_bytes = {node_id: 0 for node_id in bytes_by_node}
            configure_reporting(agent, bytes_by_node)
            requests = []
            responses = [{"interval": 5, "fast_mode": False}] * 3

            with mock.patch.object(agent.urllib.request, "urlopen", side_effect=post_recorder(requests, responses)):
                for _ in range(3):
                    self.assertTrue(agent.report_status(current_nodes, [], force_http=True))

            self.assertEqual([len(request["node_traffic"]) for request in requests], [200, 200, 1])
            self.assertEqual(len({request["report_id"] for request in requests}), 3)
            self.assertTrue(all(request["report_id"].startswith(f"{VPS_IP}:") for request in requests))
            self.assertEqual(agent.last_reported_bytes, bytes_by_node)
            self.assertIsNone(json.loads(state_path.read_text(encoding="utf-8"))["pending"])

    def test_queue_dispatches_one_fresh_batch_and_keeps_ws_status_small(self):
        with tempfile.TemporaryDirectory() as workdir:
            agent, state_path = load_agent(workdir, "agent_report_fresh_status")
            current_nodes = nodes(201)
            bytes_by_node = {node["id"]: 100 for node in current_nodes}
            agent.last_reported_bytes = {node_id: 0 for node_id in bytes_by_node}
            configure_reporting(agent, bytes_by_node)
            status_sample = {"value": 1}
            agent.get_system_status = lambda interval: {"sample": status_sample["value"]}
            realtime = FakeRealtime()
            agent.realtime_channel = realtime
            # Recent status-only HTTP must not block traffic batch drain.
            agent.last_http_report = agent.time.time()
            requests = []

            with mock.patch.object(agent.urllib.request, "urlopen", side_effect=post_recorder(requests, [{"interval": 5, "fast_mode": False}] * 2)):
                self.assertTrue(agent.report_status(current_nodes, []))
                self.assertEqual(len(requests), 1)
                self.assertEqual(len(requests[0]["node_traffic"]), 200)
                self.assertEqual(requests[0]["sample"], 1)
                self.assertNotIn("node_traffic", realtime.messages[0][0])
                queued = json.loads(state_path.read_text(encoding="utf-8"))["pending"]
                self.assertEqual(len(queued["batches"]), 1)
                self.assertIsNone(queued["batches"][0]["payload"])

                status_sample["value"] = 2
                self.assertTrue(agent.report_status(current_nodes, []))
                self.assertEqual(len(requests), 2)
                self.assertEqual(requests[1]["sample"], 2)
                self.assertIsNone(json.loads(state_path.read_text(encoding="utf-8"))["pending"])

    def test_empty_traffic_keeps_idle_cadence_and_still_cleans_baseline(self):
        with tempfile.TemporaryDirectory() as workdir:
            agent, state_path = load_agent(workdir, "agent_report_empty")
            current_nodes = nodes(1)
            node_id = current_nodes[0]["id"]
            configure_reporting(agent, {node_id: 0})
            agent.last_reported_bytes = {node_id: 100}
            agent.realtime_channel = FakeRealtime()
            agent.last_http_report = agent.time.time()
            requests = []

            with mock.patch.object(agent.urllib.request, "urlopen", side_effect=post_recorder(requests, [{"interval": 5, "fast_mode": False}])):
                self.assertTrue(agent.report_status(current_nodes, []))
                self.assertEqual(requests, [])
                # A status-only report must not activate the traffic queue's
                # five-second drain cadence.
                self.assertFalse(agent.pending_report_batches)
                self.assertIsNotNone(agent.pending_status_report)
                self.assertTrue(json.loads(state_path.read_text(encoding="utf-8"))["pending"]["status_only"])
                self.assertTrue(agent.report_status(current_nodes, [], force_http=True))

            self.assertEqual(agent.last_reported_bytes, {node_id: 0})
            self.assertIsNone(json.loads(state_path.read_text(encoding="utf-8"))["pending"])

    def test_empty_status_reuses_failed_payload_after_restart(self):
        with tempfile.TemporaryDirectory() as workdir:
            current_nodes = nodes(1)
            node_id = current_nodes[0]["id"]
            agent, state_path = load_agent(workdir, "agent_report_empty_failure")
            configure_reporting(agent, {node_id: 0})
            agent.last_reported_bytes = {node_id: 100}
            agent.get_system_status = lambda interval: {"sample": 1}
            first_attempts = []

            with mock.patch.object(agent.urllib.request, "urlopen", side_effect=post_recorder(first_attempts, [URLError("offline")])):
                self.assertFalse(agent.report_status(current_nodes, [], force_http=True))

            pending = json.loads(state_path.read_text(encoding="utf-8"))["pending"]
            self.assertTrue(pending["status_only"])
            self.assertIsInstance(pending["payload"], dict)

            restarted, _ = load_agent(workdir, "agent_report_empty_restart")
            configure_reporting(restarted, {node_id: 0})
            restarted.get_system_status = lambda interval: {"sample": 2}
            resumed_attempts = []
            with mock.patch.object(restarted.urllib.request, "urlopen", side_effect=post_recorder(resumed_attempts, [{"interval": 5, "fast_mode": False}])):
                self.assertTrue(restarted.report_status(current_nodes, [], force_http=True))

            self.assertEqual(resumed_attempts, [pending["payload"]])
            self.assertEqual(restarted.last_reported_bytes, {node_id: 0})
            self.assertIsNone(json.loads(state_path.read_text(encoding="utf-8"))["pending"])

    def test_restart_reuses_unsuccessful_batch_payloads_and_ids(self):
        with tempfile.TemporaryDirectory() as workdir:
            agent, state_path = load_agent(workdir, "agent_report_failure")
            current_nodes = nodes(401)
            bytes_by_node = {node["id"]: 100 for node in current_nodes}
            agent.last_reported_bytes = {node_id: 0 for node_id in bytes_by_node}
            configure_reporting(agent, bytes_by_node)
            first_attempts = []
            outcomes = [{"interval": 5, "fast_mode": False}, URLError("offline")]

            with mock.patch.object(agent.urllib.request, "urlopen", side_effect=post_recorder(first_attempts, outcomes)):
                self.assertTrue(agent.report_status(current_nodes, [], force_http=True))
                self.assertFalse(agent.report_status(current_nodes, [], force_http=True))

            persisted = json.loads(state_path.read_text(encoding="utf-8"))
            outstanding = persisted["pending"]["batches"]
            self.assertEqual(len(first_attempts), 2)
            self.assertEqual(len(outstanding), 2)
            self.assertTrue(all(agent.last_reported_bytes[node["id"]] == 100 for node in current_nodes[:200]))
            self.assertTrue(all(agent.last_reported_bytes[node["id"]] == 0 for node in current_nodes[200:]))
            self.assertIsInstance(outstanding[0]["payload"], dict)
            self.assertIsNone(outstanding[1]["payload"])

            restarted, _ = load_agent(workdir, "agent_report_restart")
            configure_reporting(restarted, bytes_by_node)
            resumed_attempts = []
            outcomes = [{"interval": 5, "fast_mode": False}] * 2
            with mock.patch.object(restarted.urllib.request, "urlopen", side_effect=post_recorder(resumed_attempts, outcomes)):
                for _ in range(2):
                    self.assertTrue(restarted.report_status(current_nodes, [], force_http=True))

            self.assertEqual(resumed_attempts[0], outstanding[0]["payload"])
            self.assertEqual(resumed_attempts[1]["report_id"], outstanding[1]["report_id"])
            self.assertEqual(resumed_attempts[1]["node_traffic"], outstanding[1]["node_traffic"])
            self.assertEqual(restarted.last_reported_bytes, bytes_by_node)
            self.assertIsNone(json.loads(state_path.read_text(encoding="utf-8"))["pending"])

    def test_legacy_oversized_pending_report_is_migrated_to_batches(self):
        with tempfile.TemporaryDirectory() as workdir:
            config_path = Path(workdir) / "config.json"
            config_path.write_text(json.dumps({
                "api_url": "https://panel.example.test/api/config",
                "report_url": "https://panel.example.test/api/report",
                "ip": VPS_IP,
                "token": "test-token",
            }), encoding="utf-8")
            state_path = Path(workdir) / "traffic-state.json"
            current_nodes = nodes(201)
            entries = [{"id": node["id"], "delta_bytes": 25} for node in current_nodes]
            report_bytes = {node["id"]: 25 for node in current_nodes}
            legacy_id = f"{VPS_IP}:legacy"
            state_path.write_text(json.dumps({
                "last_reported_bytes": {node["id"]: 0 for node in current_nodes},
                "pending": {
                    "report_id": legacy_id,
                    "report_bytes": report_bytes,
                    "node_traffic": entries,
                    "payload": {"ip": VPS_IP, "report_id": legacy_id, "node_traffic": entries, "cpu": 1},
                },
            }), encoding="utf-8")

            agent, _ = load_agent(workdir, "agent_report_legacy")
            configure_reporting(agent, report_bytes)
            requests = []
            outcomes = [{"interval": 5, "fast_mode": False}] * 2
            with mock.patch.object(agent.urllib.request, "urlopen", side_effect=post_recorder(requests, outcomes)):
                for _ in range(2):
                    self.assertTrue(agent.report_status(current_nodes, [], force_http=True))

            self.assertEqual([len(request["node_traffic"]) for request in requests], [200, 1])
            self.assertEqual([request["report_id"] for request in requests], [f"{legacy_id}:0", f"{legacy_id}:1"])
            self.assertEqual(agent.last_reported_bytes, report_bytes)

    def test_legacy_single_pending_keeps_its_id_and_payload(self):
        with tempfile.TemporaryDirectory() as workdir:
            config_path = Path(workdir) / "config.json"
            config_path.write_text(json.dumps({
                "api_url": "https://panel.example.test/api/config",
                "report_url": "https://panel.example.test/api/report",
                "ip": VPS_IP,
                "token": "test-token",
            }), encoding="utf-8")
            state_path = Path(workdir) / "traffic-state.json"
            current_nodes = nodes(1)
            entry = {"id": current_nodes[0]["id"], "delta_bytes": 50}
            legacy_id = f"{VPS_IP}:legacy-single"
            legacy_payload = {"ip": VPS_IP, "report_id": legacy_id, "node_traffic": [entry], "cpu": 99}
            state_path.write_text(json.dumps({
                "last_reported_bytes": {entry["id"]: 0},
                "pending": {
                    "report_id": legacy_id,
                    "report_bytes": {entry["id"]: 50},
                    "node_traffic": [entry],
                    "payload": legacy_payload,
                },
            }), encoding="utf-8")

            agent, _ = load_agent(workdir, "agent_report_legacy_single")
            configure_reporting(agent, {entry["id"]: 50})
            requests = []
            with mock.patch.object(agent.urllib.request, "urlopen", side_effect=post_recorder(requests, [{"interval": 5, "fast_mode": False}])):
                self.assertTrue(agent.report_status(current_nodes, [], force_http=True))

            self.assertEqual(requests, [legacy_payload])
            self.assertEqual(agent.last_reported_bytes, {entry["id"]: 50})


if __name__ == "__main__":
    unittest.main()
