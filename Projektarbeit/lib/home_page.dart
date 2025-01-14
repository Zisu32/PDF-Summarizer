import 'dart:io';
import 'package:dash_chat_2/dash_chat_2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

const Color teal = Colors.teal;
const Color grey = Colors.grey;
const Color white = Colors.white;
const Color black = Colors.black12;

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final Gemini gemini = Gemini.instance;
  List<ChatMessage> messages = [];
  ChatUser currentUser = ChatUser(id: "0", firstName: "You");
  ChatUser geminiUser = ChatUser(id: "1", firstName: "Gemini");
  bool _isSummaryAvailable = false;

  @override
  void initState() {
    super.initState();
    _addWelcomeMessage();
  }

  void _addWelcomeMessage() {
    ChatMessage welcomeMessage = ChatMessage(
        user: geminiUser,
        createdAt: DateTime.now(),
        text:
            "Hello! I'm Gemini, your assistant for summarizing PDF files. To upload a PDF for summary, just tap the green button in the bottom right corner.");

    setState(() {
      messages = [welcomeMessage, ...messages];
    });
  }

  void _downloadResponseAsPDF() async {
    if (messages.isNotEmpty) {
      ChatMessage? latestGeminiResponse =
      messages.firstWhere((message) => message.user == geminiUser);

      // Create a PDF document
      final PdfDocument document = PdfDocument();
      final PdfStandardFont font = PdfStandardFont(PdfFontFamily.helvetica, 12);
      const double margin = 40.0; // Margin for A4 page

      // Define the layout area within the page (excluding margins)
      const double pageWidth = 595.0;
      const double pageHeight = 842.0;
      const Rect layoutRectangle = Rect.fromLTWH(
        margin, // Left margin
        margin + 40.0, // Top margin (leave space for title)
        pageWidth - 2 * margin, // Width excluding margins
        pageHeight - 2 * margin - 40.0, // Height excluding margins and title space
      );

      String responseText = latestGeminiResponse.text;

      // Add a title to the first page
      PdfPage currentPage = document.pages.add();
      final PdfGraphics graphics = currentPage.graphics;
      final PdfStandardFont titleFont = PdfStandardFont(PdfFontFamily.helvetica, 18);
      const String title = "Gemini Response from the PDF Summarizer Tool";
      Size titleSize = titleFont.measureString(title);
      graphics.drawString(
        title,
        titleFont,
        bounds: Rect.fromLTWH(
          (pageWidth - titleSize.width) / 2, // Center horizontally
          margin / 2, // Place above the content margin
          titleSize.width,
          titleSize.height,
        ),
      );

      // Create a PdfTextElement for multi-page text layout
      PdfTextElement textElement = PdfTextElement(
        text: responseText,
        font: font,
      );

      // Initialize layout format
      PdfLayoutFormat format = PdfLayoutFormat(
        layoutType: PdfLayoutType.paginate,
        breakType: PdfLayoutBreakType.fitPage,
      );

      // Draw the text within the defined layout rectangle
      textElement.draw(
        page: currentPage,
        bounds: layoutRectangle,
        format: format,
      );

      // Save document
      final directory = await getApplicationDocumentsDirectory();
      String formattedDate = DateFormat('yy-MM-dd').format(DateTime.now());
      String path = "${directory.path}/${formattedDate}_GeminiSummary.pdf";
      File file = File(path);
      await file.writeAsBytes(await document.save());
      document.dispose();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("PDF saved at: $path")),
      );
      print(path);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No summary to save.")),
      );
    }
  }


  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Dialog(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Text("Analyzing PDF, please wait..."),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: teal,
        centerTitle: true,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/PDF-SumLogo.png',
              height: 30, // Adjust the height as needed
            )
          ],
        ),
      ),
      body: _bodyUI(),
    );
  }

  Widget _bodyUI() {
    return Container(
      color: black,
      child: DashChat(
        inputOptions: InputOptions(
          sendButtonBuilder: (void Function()? onSend) {
            return IconButton(
              onPressed: onSend,
              icon: const Icon(
                Icons.send,
                color: teal,
              ),
            );
          },
          trailing: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(width: 10),
                Container(
                  decoration: const BoxDecoration(
                    color: teal,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: _sendPDFMessage,
                    icon: const Icon(
                      Icons.picture_as_pdf,
                      color: white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: _isSummaryAvailable ? teal : Colors.black12,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed:
                        _isSummaryAvailable ? _downloadResponseAsPDF : null,
                    icon: Icon(
                      Icons.download,
                      color: _isSummaryAvailable ? white : Colors.black12,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        currentUser: currentUser,
        onSend: _sendMessage,
        messages: messages,
        messageOptions: MessageOptions(
          currentUserContainerColor: Colors.teal,
          currentUserTextColor: Colors.white,
          messageTextBuilder: (ChatMessage message,
              ChatMessage? previousMessage, ChatMessage? nextMessage) {
            return _buildMarkdownMessage(message.text, message.user);
          },
        ),
      ),
    );
  }

  // Helper method to build the Markdown widget for chat messages
  Widget _buildMarkdownMessage(String text, ChatUser user) {
    return MarkdownBody(
      data: text,
      styleSheet: MarkdownStyleSheet(
        p: TextStyle(
          color: user.id == currentUser.id ? Colors.white : Colors.black,
        ),
      ),
    );
  }

  void _sendMessage(ChatMessage chatMessage) {
    setState(() {
      messages = [chatMessage, ...messages];
    });
    try {
      String userQuestion = chatMessage.text;
      StringBuffer responseBuffer = StringBuffer();

      gemini.streamGenerateContent(userQuestion).listen((event) {
        String partialResponse = event.content?.parts
                ?.fold("", (previous, current) => "$previous${current.text}") ??
            "";

        responseBuffer.write(partialResponse);
      }, onDone: () {
        String completeResponse = responseBuffer.toString();

        setState(() {
          if (messages.isNotEmpty && messages.first.user == geminiUser) {
            messages[0] = ChatMessage(
              user: geminiUser,
              createdAt: DateTime.now(),
              text: completeResponse,
            );
          } else {
            messages = [
              ChatMessage(
                user: geminiUser,
                createdAt: DateTime.now(),
                text: completeResponse,
              ),
              ...messages,
            ];
          }
        });
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error during PDF analysis.')),
      );
    }
  }

  void _sendPDFMessage() async {
    _showLoadingDialog();
    FilePickerResult? result;
    File? file;
    String? pdfText;

    try {
      result = await FilePicker.platform.pickFiles();

      if (result == null) {
        Navigator.of(context).pop(); // Close loadingDialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No file selected')),
        );
        print("No file selected");
        return;
      } else {
        file = File(result.files.single.path!);
      }
    } catch (e) {
      Navigator.of(context).pop(); // Close loadingDialog
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error during FilePicking')),
      );
      print("Error during FilePicking: $e");
      return;
    }

    try {
      pdfText = await _extractTextFromPDF(file);

      if (pdfText.isEmpty) {
        Navigator.of(context).pop(); // Close loadingDialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No text in PDF to extract.')),
        );
        print("No text in PDF to extract.");
        return;
      }
    } catch (e) {
      Navigator.of(context).pop(); // Close loadingDialog
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error during text extraction')),
      );
      print("Error during text extraction: $e");
      return;
    }
    try {
      StringBuffer responseBuffer = StringBuffer();
      gemini
          .streamGenerateContent(
              "Summarize this PDF:\n$pdfText\nstart your response with:\nHere is your summarized PDF based on your uploaded PDF document\nend your respone with:\nIf you like the summary you can download the answer by pressing the green download button")
          .listen(
        (event) {
          String partialResponse = event.content?.parts?.fold(
                  "", (previous, current) => "$previous${current.text}") ??
              "";
          responseBuffer.write(partialResponse);
        },
        onDone: () {
          String completeResponse = responseBuffer.toString();

          setState(() {
            if (messages.isNotEmpty && messages.first.user == geminiUser) {
              messages = [
                ChatMessage(
                  user: geminiUser,
                  createdAt: DateTime.now(),
                  text: completeResponse,
                ),
                ...messages,
              ];
            } else {
              messages = [
                ChatMessage(
                  user: geminiUser,
                  createdAt: DateTime.now(),
                  text: completeResponse,
                ),
                ...messages,
              ];
            }
            _isSummaryAvailable = true;
          });
        },
      );
      Navigator.of(context).pop();
    } catch (e) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error during PDF summarization.')),
      );
    }
  }
}

Future<String> _extractTextFromPDF(File file) async {
  try {
    String extractedText = "";
    final PdfDocument document =
        PdfDocument(inputBytes: file.readAsBytesSync());

    for (int i = 0; i < document.pages.count; i++) {
      extractedText += PdfTextExtractor(document)
          .extractText(startPageIndex: i, endPageIndex: i);
    }

    // Dispose the document
    document.dispose();

    return extractedText;
  } catch (e) {
    print("Error extracting text from PDF: $e");
    return "";
  }
}
