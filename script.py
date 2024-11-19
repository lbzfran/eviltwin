from mitmproxy import ctx, http


class ChangeHTTPCode:
    filter = "httpforever.com"
    def response(self, flow: http.HTTPFlow) -> None:
        if (self.filter in flow.request.pretty_url):
            flow.response.status_code = 503

class DuckAttackCode:
    css = """
    <style>
        .duck {
            width: 50px;
            height: 50px;
            font-size: 50px;
            position: absolute;
            top: 50%;
            right: 50px;
            transition: left  0.05s;
        }
    </style>
    """
    jscript = """
    <p class="duck">&#129414</p>
    <script>
        let position = 0;
        const duck_object = document.querySelector('.duck');

        setInterval( () => {
            position += 1;
            duck_object.style.right = position + 'px';

            if (position > window.innerWidth) {
                position = 50;
            }
        }, -50);
    </script>
    """
    def response(self, flow: http.HTTPFlow) -> None:
        ctx.log.info("hihi! i'm about to corrupt the http pool!")
        ctx.log.info(flow.request.pretty_url)

        if flow.response.headers.get("Content-Type", "").startswith("text/html"):
            if flow.response.content:
                html = flow.response.content.decode("utf-8", errors='ignore')

                if "<head>" in html:
                    html = html.replace("<head>", f"<head>{self.css}")

                if "</body>" in html:
                    html = html.replace("</body>", f"{self.jscript}</body>")
                    ctx.log.info("corrupted html")
                    ctx.log.info(html)

                flow.response.content = html.encode('utf-8')

class FlipHTMLCode:
    css = """
    <style>
        body {
            transform: rotate(180deg);
            -webkit-transform: rotate(180deg);
            transform-origin: center;
            width: 100%;
            height: 100%;
        }
    </style>
    """
    def response(self, flow: http.HTTPFlow) -> None:
        ctx.log.info("hihi! i'm about to corrupt the http pool!")
        ctx.log.info(flow.request.pretty_url)

        if flow.response.headers.get("Content-Type", "").startswith("text/html"):
            if flow.response.content:
                html = flow.response.content.decode("utf-8", errors='ignore')

                if "<head>" in html:
                    html = html.replace("<head>", f"<head>{self.css}")
                    ctx.log.info(html)


                flow.response.content = html.encode('utf-8')




addons = [FlipHTMLCode(),DuckAttackCode()]
