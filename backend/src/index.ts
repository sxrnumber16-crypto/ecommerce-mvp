import { createApp } from "./app.js";
import { config } from "./config.js";

const app = createApp();

app.listen(config.port, config.host, () => {
  console.log(`listening on ${config.host}:${config.port}`);
});
