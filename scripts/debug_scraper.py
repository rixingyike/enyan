from playwright.sync_api import sync_playwright

def run():
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        page = browser.new_page()
        page.goto("https://www.bible.com/zh-CN/bible/48/LEV.1.CUNPSS-%E7%A5%9E")
        page.wait_for_load_state("networkidle")
        
        # Save HTML
        with open("debug_page.html", "w") as f:
            f.write(page.content())
            
        print("Page title:", page.title())
        
        # Try to find verse containers
        # Common classes in YouVersion web: .ChapterContent_chapter__...
        # Let's list some classes
        classes = page.evaluate("""() => {
            return Array.from(document.querySelectorAll('*')).map(e => e.className).filter(c => c && typeof c === 'string').slice(0, 100);
        }""")
        print("Classes found:", classes[:20])
        
        browser.close()

if __name__ == "__main__":
    run()
