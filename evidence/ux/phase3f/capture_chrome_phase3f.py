import asyncio
import os
import shutil
from playwright.async_api import async_playwright

EVIDENCE_DIR = r"C:\AK\HOCKI8\PRM393\PRM-Akkhanh-UIUX\ChatAIProject\evidence\ux\phase3f"
ARTIFACT_DIR = r"C:\Users\Admin\.gemini\antigravity\brain\67d28388-7525-4fe6-8c37-a25937481db5\phase3f"

os.makedirs(EVIDENCE_DIR, exist_ok=True)
os.makedirs(ARTIFACT_DIR, exist_ok=True)

async def capture(page, name, wait_sec=2.0):
    await page.wait_for_timeout(int(wait_sec * 1000))
    path_evidence = os.path.join(EVIDENCE_DIR, f"{name}.png")
    path_artifact = os.path.join(ARTIFACT_DIR, f"{name}.png")
    await page.screenshot(path=path_evidence)
    shutil.copyfile(path_evidence, path_artifact)
    print(f"Captured: {name}.png ({os.path.getsize(path_evidence)} bytes)")

async def main():
    async with async_playwright() as p:
        browser = await p.chromium.launch(
            headless=True,
            executable_path=r"C:\Program Files\Google\Chrome\Application\chrome.exe"
        )

        # ----------------------------------------------------
        # 1. Home Screen (390x844, Light & Dark)
        # ----------------------------------------------------
        ctx = await browser.new_context(viewport={'width': 390, 'height': 844}, device_scale_factor=2)
        page = await ctx.new_page()

        await page.goto("http://localhost:8085/?demo=1&theme=light&tab=home")
        await page.evaluate("localStorage.clear()")
        await page.reload(wait_until="networkidle")
        await capture(page, "01_home_checklist_step2_390x844_light", 3.0)

        await page.goto("http://localhost:8085/?demo=1&theme=dark&tab=home")
        await page.evaluate("localStorage.clear()")
        await page.reload(wait_until="networkidle")
        await capture(page, "01_home_checklist_step2_390x844_dark", 3.0)
        await ctx.close()

        # ----------------------------------------------------
        # 2. Roadmap Screen (360x640, Initial Viewport)
        # ----------------------------------------------------
        ctx_small = await browser.new_context(viewport={'width': 360, 'height': 640}, device_scale_factor=2)
        page_small = await ctx_small.new_page()
        await page_small.goto("http://localhost:8085/?demo=1&theme=light&tab=roadmap")
        await page_small.evaluate("localStorage.clear()")
        await page_small.reload(wait_until="networkidle")
        await capture(page_small, "02_roadmap_360x640_initial_light", 3.0)
        await ctx_small.close()

        # ----------------------------------------------------
        # 3. Graph View Screen (390x844)
        # ----------------------------------------------------
        ctx_graph = await browser.new_context(viewport={'width': 390, 'height': 844}, device_scale_factor=2)
        page_graph = await ctx_graph.new_page()

        await page_graph.goto("http://localhost:8085/?demo=1&theme=light&tab=roadmap&view=graph", wait_until="networkidle")
        await capture(page_graph, "03_graph_default_legend_390x844_light", 3.0)

        await page_graph.goto("http://localhost:8085/?demo=1&theme=dark&tab=roadmap&view=graph", wait_until="networkidle")
        await capture(page_graph, "03_graph_default_legend_390x844_dark", 3.0)

        # Node click for chain highlight
        await page_graph.goto("http://localhost:8085/?demo=1&theme=light&tab=roadmap&view=graph", wait_until="networkidle")
        await page_graph.wait_for_timeout(2500)
        await page_graph.mouse.click(195, 420)
        await page_graph.wait_for_timeout(1000)
        await capture(page_graph, "03_graph_node_selected_390x844_light", 1.5)
        await ctx_graph.close()

        # ----------------------------------------------------
        # 4. Settings Screen - Profile Clean & Dirty
        # ----------------------------------------------------
        ctx_settings = await browser.new_context(viewport={'width': 390, 'height': 844}, device_scale_factor=2)
        page_settings = await ctx_settings.new_page()

        await page_settings.goto("http://localhost:8085/?demo=1&theme=light&tab=settings&scroll=profile", wait_until="networkidle")
        await page_settings.evaluate("localStorage.clear()")
        await page_settings.reload(wait_until="networkidle")
        await capture(page_settings, "04_settings_profile_clean_390x844_light", 2.5)

        # Click on "Đạt điểm cao" chip (located around x=220, y=310)
        await page_settings.mouse.click(220, 310)
        await page_settings.wait_for_timeout(1000)
        await capture(page_settings, "04_settings_profile_dirty_390x844_light", 1.5)

        # ----------------------------------------------------
        # 5. Settings Screen - Data section & Delete transcript disabled
        # ----------------------------------------------------
        await page_settings.goto("http://localhost:8085/?demo=1&theme=light&tab=settings&scroll=data", wait_until="networkidle")
        await capture(page_settings, "05_settings_delete_transcript_disabled_390x844_light", 2.5)

        # ----------------------------------------------------
        # 6. Settings Screen - Release Developer Mode Hidden & Unlocked
        # ----------------------------------------------------
        await page_settings.goto("http://localhost:8085/?demo=1&theme=light&tab=settings&scroll=bottom", wait_until="networkidle")
        await capture(page_settings, "06_settings_developer_mode_hidden_release_390x844_light", 2.5)

        # Tap 7 times on version text at bottom (x=195, y=720)
        for _ in range(7):
            await page_settings.mouse.click(195, 720)
            await page_settings.wait_for_timeout(150)
        await page_settings.wait_for_timeout(1500)
        await capture(page_settings, "06_settings_developer_mode_unlocked_7taps_390x844_light", 1.5)

        await ctx_settings.close()
        await browser.close()
        print(">>> ALL PHASE 3F CHROME SCREENSHOTS COMPLETED! <<<")

if __name__ == "__main__":
    asyncio.run(main())
