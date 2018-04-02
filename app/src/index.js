import './main.css';
import { Main } from './Main.elm';
import registerServiceWorker from './registerServiceWorker';

var app = Main.embed(document.getElementById('root'), {});

registerServiceWorker();

window.addEventListener("focus", function(event) {
    app.ports.windowFocus.send("focus");
}, false);
