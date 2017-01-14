window.webhelper = {
    port: 23904,

    ask: function (callback) {
        var host = location.protocol + '//' + location.hostname;
        var req = new XMLHttpRequest();
        req.open('POST', host + ':' + this.port + '/begin', false);
        req.onload = function () {
            console.log((req.status == 200) ? 'Ready!                  (ﾉ≧∇≦)ﾉ ﾐ ┸━┸' : 'Build error');
            callback(req.status == 200);
        };
        console.log('Waiting for build...    (ヘ･_･)ヘ ┳━┳');
        req.send();
    },

    redirectToStatus: function () {
        var host = location.protocol + '//' + location.hostname;
        window.location = host + ':' + this.port + '/status';
    },

    redirectToGame: function () {
        var host = location.protocol + '//' + location.hostname;
        for (var port = 8000; port <= 8100; port++) {
            var image = new Image();
            image.src = host + ':' + port + '/res/favicon.ico';
            (function (port) {
                image.onload = function () {
                    window.location = host + ':' + port;
                };
            })(port);
        }
    },
};
