# Roteiro - Portar o PDFium para Dart

**Objetivo:** Criar um port de alto desempenho em Dart puro da biblioteca PDFium para renderização de PDF.

**Referência:** `C:\MyDartProjects\pdfium_dart\referencias\pdfium_cpp`

---

## Fase 1: Core Runtime (fxcrt) ✅ CONCLUÍDO

### 1.1 Tipos Básicos ✅
- [x] `fx_types.dart` - PdfError, Result, ByteSpan, PdfObjectType, PageRotation
- [x] `fx_coordinates.dart` - FxPoint, FxPointF, FxRect, FxRectInt, FxMatrix
- [x] `fx_string.dart` - ByteString, WideString, PdfStringCodec
- [x] `fx_stream.dart` - SeekableReadStream, FileReadStream, MemoryReadStream
- [x] `binary_buffer.dart` - BinaryBuffer para construção de dados binários

### 1.2 Testes Core ✅
- [x] Testes de FxPoint, FxRect, FxMatrix
- [x] Testes de ByteString, WideString
- [x] Testes de Result, ByteSpan

---

## Fase 2: Parser PDF (fpdfapi/parser) ✅ CONCLUÍDO

### 2.1 Objetos PDF ✅
- [x] `pdf_object.dart` - Classe base PdfObject
- [x] `pdf_boolean.dart` - PdfBoolean
- [x] `pdf_number.dart` - PdfNumber (integer e real)
- [x] `pdf_string.dart` - PdfString (literal e hex)
- [x] `pdf_name.dart` - PdfName
- [x] `pdf_null.dart` - PdfNull
- [x] `pdf_array.dart` - PdfArray
- [x] `pdf_dictionary.dart` - PdfDictionary
- [x] `pdf_stream.dart` - PdfStream com decodificação
- [x] `pdf_reference.dart` - PdfReference (indirect objects)

### 2.2 Parser ✅
- [x] `pdf_syntax_parser.dart` - Parser de sintaxe PDF
- [x] `pdf_parser.dart` - Parser principal do documento
- [x] `pdf_cross_ref_table.dart` - Tabela de referências cruzadas
- [x] `pdf_document.dart` - Container do documento

### 2.3 Testes Parser ✅
- [x] Parse de números, strings, nomes
- [x] Parse de arrays e dicionários
- [x] Parse de referências

---

## Fase 3: Gráficos (fxge) ✅ CONCLUÍDO

### 3.1 Device Independent Bitmap ✅
- [x] `fx_dib.dart` - FxColor, FxDIBitmap, BitmapFormat
- [x] Operações de pixel (get/set)
- [x] Fill rect, draw line
- [x] Conversão para RGB/RGBA bytes
- [x] Clear com cor de fundo

### 3.2 Testes Gráficos ✅
- [x] Criação de bitmap
- [x] Clear e get/set pixel
- [x] Fill rect
- [x] Conversão para RGB bytes

---

## Fase 4: Página PDF (fpdfapi/page) ✅ CONCLUÍDO

### 4.1 Estrutura de Página ✅
- [x] `pdf_page.dart` - PdfPage com MediaBox, CropBox, rotation
- [x] `pdf_page_object.dart` - Objetos de página (path, text, image, shading)
- [x] `graphics_state.dart` - Estado gráfico (CTM, cores, fonte, etc.)

### 4.2 Content Stream ✅
- [x] `content_stream_parser.dart` - Parser de operações gráficas
- [x] `content_stream_interpreter.dart` - Executor de operações

### 4.3 Recursos ✅
- [x] `colorspace.dart` - Sistema completo de color spaces:
  - DeviceGray, DeviceRGB, DeviceCMYK
  - CalGray, CalRGB, Lab
  - ICCBased, Indexed
  - Separation, DeviceN, Pattern
- [x] `pdf_image.dart` - Manipulação de imagens XObject
- [x] `pdf_form_xobject.dart` - Form XObjects
- [x] Patterns (Tiling, Shading) com AxialShading, RadialShading

### 4.4 Testes de Página ✅ CONCLUÍDO
- [x] Content stream parser básico
- [x] ColorSpace conversions
- [x] GraphicsState
- [x] ContentStreamParser operations

---

## Fase 5: Fontes (fpdfapi/font) ✅ CONCLUÍDO

### 5.1 Sistema de Fontes ✅
- [x] `pdf_font.dart` - Classes de fonte:
  - PdfFont (base)
  - PdfType1Font
  - PdfTrueTypeFont
  - PdfCIDFont
  - PdfType0Font (composite)
- [x] FontDescriptor
- [x] ToUnicode CMap
- [x] Métricas de glyph

### 5.2 Testes de Fontes ✅ CONCLUÍDO
- [x] Estrutura de classes de fonte

---

## Fase 6: Renderização de Texto ✅ CONCLUÍDO

### 6.1 Text Renderer ✅
- [x] `text_renderer.dart` - Renderização de texto
- [x] Posicionamento de texto (Td, Tm)
- [x] Tj, TJ operators
- [x] Extração de texto

### 6.2 Testes de Texto ✅ CONCLUÍDO
- [x] Operações de texto no parser

---

## Fase 7: API Pública ✅ CONCLUÍDO

### 7.1 Public API ✅
- [x] `fpdf_view.dart`:
  - PdfiumLibrary.init() / destroy()
  - Fpdf.loadDocument()
  - PdfRenderer com renderPage()
  - RenderFlags
  - PdfLoadResult

### 7.2 Testes API ✅ CONCLUÍDO
- [x] Inicialização da biblioteca
- [x] Carregamento de documento
- [x] Renderização de página

---

## Fase 8: Funcionalidades Avançadas ✅ CONCLUÍDO

### 8.1 Segurança ✅ CONCLUÍDO
- [x] `pdf_crypt.dart` - Módulo de criptografia completo:
  - RC4 (stream cipher para PDF 1.0-1.3)
  - AESCrypt (AES-CBC para PDF 1.5+)
  - MD5Hash, SHA256Hash, SHA384Hash, SHA512Hash
  - PdfSecurityHandler (autenticação e descriptografia)
  - PdfPermissions (flags de permissão)
- [x] Descriptografia RC4
- [x] Descriptografia AES-128/256
- [x] Verificação de permissões
- [x] Testes de criptografia (16 testes)

### 8.2 Anotações ✅ CONCLUÍDO
- [x] `pdf_annotation.dart` - Módulo completo de anotações:
  - AnnotationSubtype enum (29 tipos)
  - AnnotationFlags (10 flags)
  - PdfAnnotation (classe base)
  - PdfLinkAnnotation, PdfTextAnnotation
  - PdfFreeTextAnnotation, PdfInkAnnotation
  - PdfLineAnnotation, PdfStampAnnotation
  - PdfAction (GoTo, URI, JavaScript, Named, etc.)
  - PdfDestination (navegação no documento)
  - PdfAnnotationList (gerenciamento por página)
- [x] Testes de anotações (34 testes)

### 8.3 Formulários ✅ CONCLUÍDO
- [x] `pdf_form.dart` - Módulo completo de formulários interativos:
  - FormFieldType enum (8 tipos: text, checkbox, radio, combo, list, button, signature)
  - FormFieldFlags (common, button, text, choice flags)
  - PdfFormControl (widget annotations)
  - PdfFormField (campo base com herança de atributos)
  - ChoiceOption (opções para combo/list box)
  - PdfInteractiveForm (gerenciamento do AcroForm)
  - extractFormData utility
  - Extensions: TextFieldExtension, ChoiceFieldExtension, ButtonFieldExtension
- [x] Testes de formulários (36 testes)

### 8.4 Assinaturas Digitais 📋 PLANEJADO
- [ ] Verificação de assinatura
- [ ] Extração de certificados

---

## Fase 9: Otimização 📋 PLANEJADO

### 9.1 Performance
- [ ] Cache de objetos parsed
- [ ] Lazy loading de páginas
- [ ] Pool de buffers
- [ ] Renderização incremental

### 9.2 Memória
- [ ] Limite de cache de imagens
- [ ] Streaming de dados grandes
- [ ] Garbage collection friendly

---

## Status Atual

| Componente | Status | Testes |
|------------|--------|--------|
| Core Types | ✅ 100% | ✅ 154 testes total |
| Parser | ✅ 100% | ✅ Completo |
| Graphics | ✅ 100% | ✅ Completo |
| Page | ✅ 100% | ✅ Completo |
| Fonts | ✅ 100% | ✅ Básico |
| Text | ✅ 100% | ✅ Básico |
| API | ✅ 100% | ✅ Completo |
| Segurança | ✅ 100% | ✅ 16 testes |
| Anotações | ✅ 100% | ✅ 34 testes |
| Formulários | ✅ 100% | ✅ 36 testes |
| Dependências | ✅ 100% | (AGG, FreeType, HarfBuzz) |

---

## Fase 10: Dependências Gráficas (Portadas) ✅ CONCLUÍDO
- [x] AGG (Anti-Grain Geometry) - Renderização 2D
- [x] FreeType - Engine de Fontes
- [x] HarfBuzz - Text Shaping

## Fase 11: FXCodec (Codecs de Imagem) ✅ CONCLUÍDO
- [x] `fx_codec_def.dart` - Definições básicas
- [x] `scanlinedecoder.dart` - Interface de decodificador por linha
- [x] `flate` - Flate/ZLib decode com Predictors
- [x] `fax` - CCITT Fax decode
- [x] `basic` - RunLength decode
- [x] `jpeg` - JPEG decode (Stub/Interface)
- [x] `png` - PNG decode (Stub/Interface)

## Fase 12: FPDFText (Texto e Busca) ✅ CONCLUÍDO
- [x] `cpdf_textpage.dart` - Extração de texto (Com Unicode e Posição)
- [x] `cpdf_textpagefind.dart` - Busca de texto
- [x] `pdf_content_parser.dart` - Parse de objetos da página (Texto, Paths, Imagens)

## Fase 13: Renderização (fpdfapi/render) 🚧 EM ANDAMENTO
- [ ] `cpdf_renderoptions.dart` - Opções de renderização flags
- [ ] `cpdf_rendercontext.dart` - Contexto de renderização de página
- [ ] `cpdf_renderstatus.dart` - Controlador de estado da renderização
- [ ] `cpdf_textrenderer.dart` - Renderização de objetos de texto
- [ ] `cpdf_imagerenderer.dart` - Renderização de imagens

---

## Próximos Passos

1. **Assinaturas Digitais** - Implementar verificação básica de assinaturas
   - Parser de estrutura PKCS#7
   - Extração de certificados
   - Validação de integridade

2. **Otimização** - Melhorar performance para documentos grandes
   - Cache de objetos parsed
   - Lazy loading de páginas
   - Pool de buffers

3. **Testes de Integração** - Testar com PDFs reais
   - PDFs com formulários
   - PDFs com anotações
   - PDFs criptografados

4. **Documentação** - Melhorar documentação
   - API reference
   - Exemplos de uso
   - Guia de contribuição