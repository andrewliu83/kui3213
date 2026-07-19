import { onRequest, onRequestScheduled } from '../functions/api/[[path]].js';
import realtime, { DashboardHub, VpsPresence } from '../realtime/src/index.js';

export { DashboardHub, VpsPresence };

function apiParams(pathname) {
    const segments = pathname.slice('/api/'.length).split('/').filter(Boolean);
    return { path: segments };
}

function withWorkerOrigin(env, origin) {
    return Object.assign(Object.create(env), { PAGES_ORIGIN: origin, REALTIME_URL: origin });
}

function isRealtimeRoute(pathname) {
    return pathname === '/health'
        || pathname === '/agent/ws'
        || pathname === '/dashboard/ticket'
        || pathname === '/dashboard/ws'
        || pathname === '/dashboard/snapshot'
        || pathname === '/public/ws'
        || pathname === '/notify'
        || pathname === '/public-policy'
        || pathname === '/frequency-policy';
}

export default {
    async fetch(request, env, ctx) {
        const url = new URL(request.url);
        const runtimeEnv = withWorkerOrigin(env, url.origin);

        if (url.pathname === '/api' || url.pathname.startsWith('/api/')) {
            return onRequest({ request, env: runtimeEnv, params: apiParams(url.pathname), waitUntil: ctx.waitUntil.bind(ctx) });
        }

        if (isRealtimeRoute(url.pathname)) {
            return realtime.fetch(request, runtimeEnv, ctx);
        }

        return env.ASSETS.fetch(request);
    },

    async scheduled(controller, env, ctx) {
        return onRequestScheduled({ scheduledTime: controller.scheduledTime, cron: controller.cron, env: withWorkerOrigin(env, ''), waitUntil: ctx.waitUntil.bind(ctx) });
    },
};
