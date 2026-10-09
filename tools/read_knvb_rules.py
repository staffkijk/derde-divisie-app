from pypdf import PdfReader
reader=PdfReader('knvb-2026-2027.pdf')
for i,p in enumerate(reader.pages):
 text=p.extract_text() or ''
 if 'rangorde' in text.lower() or ('periode' in text.lower() and '34' in text and '12' in text):
  print('PAGE',i+1)
  print(text[:16000])
