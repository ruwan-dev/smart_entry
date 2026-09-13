from PIL import Image
import os

files = [
    (r'C:\Users\RuwanPathirana\.gemini\antigravity\brain\b9fdbe1c-23b3-4700-8bdc-05964c74736a\.user_uploaded\media_1789288701123.png', 'gold'),
    (r'C:\Users\RuwanPathirana\.gemini\antigravity\brain\b9fdbe1c-23b3-4700-8bdc-05964c74736a\.user_uploaded\media_1789288701150.png', 'platinum'),
    (r'C:\Users\RuwanPathirana\.gemini\antigravity\brain\b9fdbe1c-23b3-4700-8bdc-05964c74736a\.user_uploaded\media_1789288701172.png', 'bronze'),
    (r'C:\Users\RuwanPathirana\.gemini\antigravity\brain\b9fdbe1c-23b3-4700-8bdc-05964c74736a\.user_uploaded\media_1789288701197.png', 'diamond'),
    (r'C:\Users\RuwanPathirana\.gemini\antigravity\brain\b9fdbe1c-23b3-4700-8bdc-05964c74736a\.user_uploaded\media_1789288701220.png', 'ruby'),
]

out_dir = r'C:\Users\RuwanPathirana\SmartEntry\assets\badges'
os.makedirs(out_dir, exist_ok=True)

def remove_white_bg(img_path, name):
    img = Image.open(img_path).convert('RGBA')
    datas = img.getdata()
    
    new_data = []
    # threshold for white
    for item in datas:
        # If the pixel is very close to white (e.g. > 240 on R, G, B)
        if item[0] > 240 and item[1] > 240 and item[2] > 240:
            # Check if it's really white or just a light color
            # We can use a soft alpha blend for anti-aliasing
            avg = (item[0] + item[1] + item[2]) / 3
            if avg > 250:
                new_data.append((255, 255, 255, 0))
            else:
                # partial transparency for anti-aliased edges
                alpha = int(255 - (avg - 240) * 17) # roughly map 240-255 to 255-0
                new_data.append((item[0], item[1], item[2], max(0, alpha)))
        else:
            new_data.append(item)
            
    img.putdata(new_data)
    out_path = os.path.join(out_dir, f'badge_{name}.png')
    img.save(out_path, 'PNG')
    print(f'Saved {out_path}')

for f, n in files:
    remove_white_bg(f, n)
