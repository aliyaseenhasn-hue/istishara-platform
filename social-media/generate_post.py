from PIL import Image, ImageDraw, ImageFont
import arabic_reshaper
from bidi.algorithm import get_display

W, H = 1080, 1350
BG = (244, 247, 250)
NAVY = (20, 43, 64)
SKY = (88, 147, 190)
SKY_LIGHT = (221, 235, 245)
TEXT = (31, 45, 58)
MUTED = (91, 108, 122)
WHITE = (255, 255, 255)

img = Image.new('RGB', (W, H), BG)
d = ImageDraw.Draw(img)

FONT_REG = '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
FONT_BOLD = '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'


def f(size, bold=False):
    return ImageFont.truetype(FONT_BOLD if bold else FONT_REG, size)


def ar(text):
    return get_display(arabic_reshaper.reshape(text))


def rtext(text, xy, font, fill, anchor='ra'):
    d.text(xy, ar(text), font=font, fill=fill, anchor=anchor)

# Header accent
d.rounded_rectangle((70, 62, 1010, 170), radius=30, fill=NAVY)
rtext('استشارة', (950, 116), f(52, True), WHITE, 'ra')
rtext('منصة قانونية عراقية', (580, 116), f(28), SKY_LIGHT, 'ra')

# Main title
rtext('استشارتك تبدأ', (950, 285), f(68, True), NAVY, 'ra')
rtext('بسؤال واضح', (950, 370), f(68, True), SKY, 'ra')

rtext('كلما كانت التفاصيل مرتبة، أصبح فهم موضوعك أسهل.', (950, 450), f(32), MUTED, 'ra')

# Tips card
d.rounded_rectangle((70, 525, 1010, 1035), radius=38, fill=WHITE)
rtext('قبل أن ترسل استشارتك:', (935, 600), f(38, True), TEXT, 'ra')

items = [
    ('01', 'لخّص المشكلة باختصار'),
    ('02', 'اذكر التواريخ المهمة'),
    ('03', 'أرفق المستندات ذات الصلة'),
]

y = 705
for num, txt in items:
    d.rounded_rectangle((855, y-36, 935, y+36), radius=18, fill=SKY_LIGHT)
    d.text((895, y), num, font=f(24, True), fill=SKY, anchor='mm')
    rtext(txt, (815, y), f(34, True), TEXT, 'ra')
    y += 115

# CTA
d.rounded_rectangle((70, 1095, 1010, 1275), radius=34, fill=NAVY)
rtext('رتّب سؤالك، ثم اطلب استشارتك عبر «استشارة».', (950, 1160), f(34, True), WHITE, 'ra')
rtext('وعي قانوني • تواصل منظم • تجربة أبسط', (950, 1218), f(27), SKY_LIGHT, 'ra')

img.save('social-media/estishara-2026-09-12.png', 'PNG', optimize=True)
