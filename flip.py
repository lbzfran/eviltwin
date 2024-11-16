from mitmproxy import ctx, http


class ChangeHTTPCode:
    filter = "httpforever.com"
    def response(self, flow: http.HTTPFlow) -> None:
        if (self.filter in flow.request.pretty_url):
            flow.response.status_code = 503


class ModifyHTMLCode:
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




addons = [ModifyHTMLCode()]
