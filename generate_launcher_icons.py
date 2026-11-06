import os
from PIL import Image, ImageDraw

def create_launcher_icons():
    src_path = r"mobile/assets/images/phytodoctor_icon.png"
    if not os.path.exists(src_path):
        raise FileNotFoundError(f"Source icon not found at {src_path}")
        
    src_img = Image.open(src_path).convert("RGBA")
    
    # Base density mapping for standard icons (48dp base)
    standard_sizes = {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }
    
    # Adaptive foreground sizes (108dp base)
    foreground_sizes = {
        "mipmap-mdpi": 108,
        "mipmap-hdpi": 162,
        "mipmap-xhdpi": 216,
        "mipmap-xxhdpi": 324,
        "mipmap-xxxhdpi": 432,
    }
    
    res_base = r"mobile/android/app/src/main/res"
    
    # 1. Generate Legacy Square/Squircle & Round Icons
    for folder, size in standard_sizes.items():
        folder_path = os.path.join(res_base, folder)
        os.makedirs(folder_path, exist_ok=True)
        
        # --- ic_launcher.png (White rounded rectangle background) ---
        icon_canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        draw = ImageDraw.Draw(icon_canvas)
        
        # Draw rounded rectangle background (white with subtle border)
        radius = int(size * 0.22)
        margin = max(1, int(size * 0.04))
        draw.rounded_rectangle(
            [margin, margin, size - margin - 1, size - margin - 1],
            radius=radius,
            fill=(255, 255, 255, 255),
            outline=(230, 235, 230, 255),
            width=max(1, int(size * 0.02))
        )
        
        # Scale and paste PhytoDoctor logo inside
        inner_size = int((size - 2 * margin) * 0.82)
        scaled_logo = src_img.resize((inner_size, inner_size), Image.Resampling.LANCZOS)
        paste_x = (size - inner_size) // 2
        paste_y = (size - inner_size) // 2
        icon_canvas.paste(scaled_logo, (paste_x, paste_y), scaled_logo)
        
        icon_path = os.path.join(folder_path, "ic_launcher.png")
        icon_canvas.save(icon_path, "PNG")
        print(f"Generated {icon_path} ({size}x{size})")
        
        # --- ic_launcher_round.png (White circular background) ---
        round_canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        round_draw = ImageDraw.Draw(round_canvas)
        round_draw.ellipse(
            [margin, margin, size - margin - 1, size - margin - 1],
            fill=(255, 255, 255, 255),
            outline=(230, 235, 230, 255),
            width=max(1, int(size * 0.02))
        )
        
        inner_round_size = int((size - 2 * margin) * 0.78)
        scaled_round_logo = src_img.resize((inner_round_size, inner_round_size), Image.Resampling.LANCZOS)
        r_paste_x = (size - inner_round_size) // 2
        r_paste_y = (size - inner_round_size) // 2
        round_canvas.paste(scaled_round_logo, (r_paste_x, r_paste_y), scaled_round_logo)
        
        round_path = os.path.join(folder_path, "ic_launcher_round.png")
        round_canvas.save(round_path, "PNG")
        print(f"Generated {round_path} ({size}x{size})")

    # 2. Generate Adaptive Foreground Icons (108dp base, transparent background, logo in safe center zone)
    for folder, fg_size in foreground_sizes.items():
        folder_path = os.path.join(res_base, folder)
        fg_canvas = Image.new("RGBA", (fg_size, fg_size), (0, 0, 0, 0))
        
        # In Android adaptive icons, the safe central circle is ~66% of the 108dp viewport
        safe_logo_size = int(fg_size * 0.58)
        scaled_fg_logo = src_img.resize((safe_logo_size, safe_logo_size), Image.Resampling.LANCZOS)
        fg_x = (fg_size - safe_logo_size) // 2
        fg_y = (fg_size - safe_logo_size) // 2
        fg_canvas.paste(scaled_fg_logo, (fg_x, fg_y), scaled_fg_logo)
        
        fg_path = os.path.join(folder_path, "ic_launcher_foreground.png")
        fg_canvas.save(fg_path, "PNG")
        print(f"Generated {fg_path} ({fg_size}x{fg_size})")

    # 3. Create colors.xml with background definition
    values_dir = os.path.join(res_base, "values")
    os.makedirs(values_dir, exist_ok=True)
    colors_xml_path = os.path.join(values_dir, "colors.xml")
    colors_content = """<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#FFFFFF</color>
</resources>
"""
    with open(colors_xml_path, "w", encoding="utf-8") as f:
        f.write(colors_content)
    print(f"Wrote {colors_xml_path}")

    # 4. Create mipmap-anydpi-v26 xml definitions
    anydpi_dir = os.path.join(res_base, "mipmap-anydpi-v26")
    os.makedirs(anydpi_dir, exist_ok=True)
    
    adaptive_xml = """<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
"""
    with open(os.path.join(anydpi_dir, "ic_launcher.xml"), "w", encoding="utf-8") as f:
        f.write(adaptive_xml)
    with open(os.path.join(anydpi_dir, "ic_launcher_round.xml"), "w", encoding="utf-8") as f:
        f.write(adaptive_xml)
    print("Wrote adaptive icon xml files in mipmap-anydpi-v26")

if __name__ == "__main__":
    create_launcher_icons()

