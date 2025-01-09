import 'dart:io';
import 'package:dash_chat_2/dash_chat_2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:path_provider/path_provider.dart';

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
  String welcomeMsg = "Hello! I'm Gemini, your assistant for summarizing PDF files. To upload a PDF for summary, just tap the green button in the bottom right corner.";
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
      text: welcomeMsg

    );

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
      final PdfPage page = document.pages.add();
      page.graphics.drawString(
        latestGeminiResponse.text,
        PdfStandardFont(PdfFontFamily.helvetica, 18),
      );

      // Get the directory to save the file
      final directory = await getApplicationDocumentsDirectory();
      String formattedDate = DateTime.now().toString().replaceAll(':', '-');
      String path = "${directory.path}/${formattedDate}_GeminiResponse.pdf";
      // Save File to path
      File file = File(path);
      await file.writeAsBytes(await document.save());

      // Dispose the document
      document.dispose();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("PDF saved at: $path")),
      );
      print(path);
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
        messageOptions: const MessageOptions(
          currentUserContainerColor: teal,
          currentUserTextColor: white,
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
      },
          onDone: () {
            // When the streaming is done, process the complete response
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
      print(e);
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
          const SnackBar(content: Text('Failed to extract text from the PDF.')),
        );
        print("Failed to extract text from the PDF.");
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
      gemini.streamGenerateContent("Summarize this PDF:\n$pdfText").listen(
        (event) {
          String partialResponse = event.content?.parts?.fold(
                  "", (previous, current) => "$previous${current.text}") ??
              "";
          responseBuffer.write(partialResponse);
        },
        onDone: () {
          // When the streaming is done, process the complete response
          String completeResponse = responseBuffer.toString();

          setState(() {
            if (messages.isNotEmpty && messages.first.user == geminiUser) {
              // Append the new response as a new message, preserving the previous one
              messages = [
                ChatMessage(
                  user: geminiUser,
                  createdAt: DateTime.now(),
                  text: completeResponse,
                ),
                ...messages, // Add previous messages without replacement
              ];
            } else {
              // Add the new response as the first message
              messages = [
                ChatMessage(
                  user: geminiUser,
                  createdAt: DateTime.now(),
                  text: completeResponse,
                ),
                ...messages,
              ];
            }
            // Ensure that only one summary message remains
            _isSummaryAvailable = true;
          });
        },
      );
      Navigator.of(context).pop();
    } catch (e) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error during PDF analysis.')),
      );
    }
  }
}

Future<String> _extractTextFromPDF(File file) async {
  try {
    // Load the PDF document
    final PdfDocument document =
        PdfDocument(inputBytes: file.readAsBytesSync());
    String extractedText = "";

    // Iterate through all pages to extract text
    for (int i = 0; i < document.pages.count; i++) {
      extractedText += PdfTextExtractor(document)
              .extractText(startPageIndex: i, endPageIndex: i) ??
          "";
    }

    // Dispose the document
    document.dispose();

    return extractedText;
  } catch (e) {
    print("Error extracting text from PDF: $e");
    return "";
  }
}
