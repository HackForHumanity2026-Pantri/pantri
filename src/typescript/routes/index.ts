import { Router } from 'express';
import IndexController from '../controllers/index';

const router = Router();
const indexController = new IndexController();

export const setRoutes = (app) => {
    app.use('/', router);
    router.get('/', indexController.index);
    // Add more routes here as needed
};