import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class BillPdfService {
  static Future<void> generateMonthlyInvoice({
    required Map<String, dynamic> bill,
    required String customerName,
    required String refNumber,
  }) async {
    final pdf = pw.Document();
    
    // බිලට අදාළ මාසය ලබා ගැනීම (උදා: MARCH 2026)
    String monthDisplay = bill['displayMonth'].toString().toUpperCase();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        // --- Header Section ---
        header: (pw.Context context) => pw.Column(children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text('NALEEN SURANGA', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
                pw.Text('Tea Purchasing & Suppliers', style: const pw.TextStyle(fontSize: 9)),
                pw.SizedBox(height: 5),
                pw.Text('Address: No 123, Tea Garden Road, Your City', style: const pw.TextStyle(fontSize: 8)),
                pw.Text('Phone: +94 71 234 5678 / +94 77 987 6543', style: const pw.TextStyle(fontSize: 8)),
              ]),
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                pw.Text('MONTHLY INVOICE', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                pw.Text(bill['displayMonth'], style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
              ]),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Divider(thickness: 1),
          pw.SizedBox(height: 8),
          // --- මෙතනට පාරිභෝගික විස්තර සහ Unit Rate එක ඇතුළත් කළා ---
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Customer: $refNumber - $customerName', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              pw.Text('UNIT RATE: Rs. ${bill['teaRate'].toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
            ],
          ),
          pw.SizedBox(height: 8),
        ]),
        // --- Footer Section ---
        footer: (pw.Context context) => pw.Column(children: [
          pw.Divider(thickness: 0.5, color: PdfColors.grey400),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Generated on: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
              pw.Text('Powered by OrbitView Innovations', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800)),
            ],
          ),
        ]),
        build: (pw.Context context) => [
          // සටහන: පාරිභෝගික විස්තර Header එකට ගත් නිසා මෙතනින් ඉවත් කළා.
          
          // --- Main Integrated Table ---
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400),
            defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
            columnWidths: {
              0: const pw.FlexColumnWidth(1),
              1: const pw.FlexColumnWidth(1),
              2: const pw.FlexColumnWidth(3.5),
              3: const pw.FlexColumnWidth(1.5),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _pdfCell('Date', b: true),
                  _pdfCell('Weight', b: true),
                  _pdfCell('Description', b: true),
                  _pdfCell('Amount', b: true),
                ],
              ),
              ...(bill['tableRows'] as List).map((row) {
                List<dynamic> items = row['items'];
                return pw.TableRow(
                  children: [
                    _pdfCell(row['date']),
                    _pdfCell(row['weight'] > 0 ? row['weight'].toStringAsFixed(1) : '-'),
                    pw.Column(
                      children: items.isEmpty 
                        ? [_pdfInternalCell('-')] 
                        : items.map((i) => _pdfInternalCell(_toEng(i['desc']), align: pw.TextAlign.left)).toList(),
                    ),
                    pw.Column(
                      children: items.isEmpty 
                        ? [_pdfInternalCell('-')] 
                        : items.map((i) => _pdfInternalCell(i['amt'].toStringAsFixed(2), align: pw.TextAlign.right)).toList(),
                    ),
                  ],
                );
              }),
            ],
          ),
          
          pw.SizedBox(height: 30),

          // --- Summary & Seal Section (Side by Side) ---
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              // 1. වම් පැත්තේ සීල් එක (Seal on Left)
              pw.Padding(
                padding: const pw.EdgeInsets.only(left: 20, bottom: 10),
                child: bill['netPayable'] < 0
                    ? _buildStamp('BALANCE DUE\n$monthDisplay', PdfColors.red700)
                    : _buildStamp('PAID\n$monthDisplay', PdfColors.green700),
              ),

              // 2. දකුණු පැත්තේ Summary එක (Summary on Right)
              pw.SizedBox(
                width: 220,
                child: pw.Column(children: [
                  _pwRow('Gross Income:', 'Rs. ${bill['grossIncome'].toStringAsFixed(2)}', isBold: true),
                  _pwRow('Transport Cost:', '- Rs. ${bill['transportCost'].toStringAsFixed(2)}'),
                  _pwRow('Goods & Advance:', '- Rs. ${bill['otherCosts'].toStringAsFixed(2)}'),
                  pw.Divider(thickness: 0.5),
                  _pwRow('Total Deductions:', '- Rs. ${bill['totalDeductions'].toStringAsFixed(2)}', color: PdfColors.red700),
                  if (bill['previousArrears'] > 0)
                    _pwRow('Previous Arrears:', '- Rs. ${bill['previousArrears'].toStringAsFixed(2)}', color: PdfColors.red700),
                  pw.Divider(thickness: 1.5),
                  _pwRow('Net Payable:', 'Rs. ${bill['netPayable'].toStringAsFixed(2)}', 
                    isBold: true, 
                    fontSize: 13, 
                    color: bill['netPayable'] < 0 ? PdfColors.red700 : PdfColors.green800
                  ),
                ]),
              ),
            ],
          ),
        ],
      ),
    );
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  // Stamp (සීල්) එක සාදන Method එක
  static pw.Widget _buildStamp(String label, PdfColor color) {
    return pw.Transform.rotate(
      angle: -0.15, // මදක් ඇලවූ පෙනුමක්
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 15, vertical: 8),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: color, width: 2.5),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        ),
        child: pw.Text(
          label,
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
            color: color,
            fontWeight: pw.FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  // PDF Cell Helpers
  static pw.Widget _pdfCell(String txt, {bool b = false}) => pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(txt, textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 9, fontWeight: b ? pw.FontWeight.bold : pw.FontWeight.normal)));

  static pw.Widget _pdfInternalCell(String txt, {pw.TextAlign align = pw.TextAlign.center}) => pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(5),
        decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
        child: pw.Text(txt, textAlign: align, style: const pw.TextStyle(fontSize: 8)),
      );

  static pw.Widget _pwRow(String label, String value, {bool isBold = false, double fontSize = 10, PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: fontSize, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal, color: color)),
          pw.Text(value, style: pw.TextStyle(fontSize: fontSize, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal, color: color)),
        ],
      ),
    );
  }

  static String _toEng(String item) {
    return item.replaceAll('පොහොර', 'Fertilizer').replaceAll('තේ පැකට්', 'Tea Packet').replaceAll('අත්තිකාරම්', 'Advance');
  }
}