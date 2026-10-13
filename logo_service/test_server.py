import io
import unittest
from PIL import Image
from server import process_logo

class LogoTests(unittest.TestCase):
    def test_transparent_logo_is_preserved(self):
        source = Image.new('RGBA', (20, 20), (120, 20, 30, 0))
        source.putpixel((10, 10), (200, 30, 40, 255))
        data = io.BytesIO()
        source.save(data, format='PNG')
        result = Image.open(io.BytesIO(process_logo(data.getvalue())))
        self.assertEqual(result.getpixel((10, 10)), (200, 30, 40, 255))
        self.assertEqual(result.getpixel((0, 0))[3], 0)

    def test_invalid_image_is_rejected(self):
        with self.assertRaises(Exception):
            process_logo(b'not-an-image')

if __name__ == '__main__':
    unittest.main()
