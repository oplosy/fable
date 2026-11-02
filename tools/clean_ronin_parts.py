"""Takes body parts out of the Ronin rig pieces they were baked into.

The torso held a copy of the front arm and the coat a copy of the front fist, so both
stayed behind when the real arm moved, and the back hand carried a piece of the coat.
Run once on the original parts: python tools/clean_ronin_parts.py
"""
from PIL import Image

DIR = "assets/characters/ronin/"
OUTLINE = (20, 16, 24, 255)


def is_cloth(pixel):
    r, g, _, a = pixel
    return a >= 40 and r > 60 and g < 70


def edit(name, change):
    path = DIR + name + ".png"
    image = Image.open(path).convert("RGBA")
    change(image)
    image.save(path)


def clear(image, left, top, right, bottom):
    for y in range(top, bottom):
        for x in range(left, right):
            image.putpixel((x, y), (0, 0, 0, 0))


def clean_torso(image):
    # The arm below the sleeve goes; the sleeve stays as the shoulder, all cloth, closed off.
    clear(image, 18, 35, 26, 44)
    red = image.getpixel((26, 30))
    for y in range(28, 35):
        for x in range(20, 26):
            r, g, b, a = image.getpixel((x, y))
            if a >= 40 and max(r, g, b) >= 50:
                image.putpixel((x, y), red)
    for x in range(19, 26):
        image.putpixel((x, 35), OUTLINE)


def clean_coat(image):
    # The fist on the coat's edge goes; the cloth gets its outline back.
    clear(image, 18, 53, 24, 59)
    for y in (55, 56, 58):
        image.putpixel((24 if y != 58 else 23, y), OUTLINE)


def move_cloth_to_coat():
    def change(image):
        coat = Image.open(DIR + "coat_tail.png").convert("RGBA")
        for y in range(image.height):
            for x in range(image.width):
                pixel = image.getpixel((x, y))
                if is_cloth(pixel):
                    image.putpixel((x, y), (0, 0, 0, 0))
                    if coat.getpixel((x, y))[3] < 40:
                        coat.putpixel((x, y), pixel)
        coat.save(DIR + "coat_tail.png")
    return change


edit("torso", clean_torso)
edit("coat_tail", clean_coat)
edit("hand_back", move_cloth_to_coat())
edit("arm_back_lower", move_cloth_to_coat())
print("Ronin parts cleaned.")
