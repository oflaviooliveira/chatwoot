import { createRouter, createWebHistory } from 'vue-router';

import routes from './routes';
import { validateRouteAccess } from '../helpers/RouteHelper';

export const router = createRouter({ history: createWebHistory(), routes });

const sensitiveRouteNames = ['auth_password_edit'];

const trackPageView = to => {
  const track = async () => {
    const { default: AnalyticsHelper } = await import(
      'dashboard/helper/AnalyticsHelper'
    );
    AnalyticsHelper.page(to.name || '', {
      path: to.path,
      name: to.name,
    });
  };

  if (window.requestIdleCallback) {
    window.requestIdleCallback(track);
  } else {
    setTimeout(track, 0);
  }
};

export const initalizeRouter = () => {
  router.beforeEach((to, _, next) => {
    if (!sensitiveRouteNames.includes(to.name)) {
      trackPageView(to);
    }

    return validateRouteAccess(to, next, window.chatwootConfig);
  });
};

export default router;
