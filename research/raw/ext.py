import re,glob,html
for f in glob.glob("*.html"):
    t=open(f,encoding="utf-8",errors="ignore").read()
    t=re.sub(r"(?is)<(script|style|noscript|svg)[^>]*>.*?</\1>"," ",t)
    t=re.sub(r"(?s)<[^>]+>"," ",t); t=html.unescape(t)
    t=re.sub(r"\s+"," ",t)[:45000]
    t=re.sub(r"(?<=[.!?\u2022]) (?=[A-Z(\u201c])","\n",t)
    open(f.replace(".html",".txt"),"w").write(t)
print("ok")
