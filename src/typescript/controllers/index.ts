export class IndexController {
    public getIndex(req, res) {
        res.send("Welcome to Pantri!");
    }

    public getHealth(req, res) {
        res.status(200).send({ status: "OK" });
    }
}