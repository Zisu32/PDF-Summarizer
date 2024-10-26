import 'dart:collection';
import 'dart:io';
import 'package:dash_chat_2/dash_chat_2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

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

  @override
  void initState() {
    super.initState();

    // Add a welcome message to the chat when the app starts
    _addWelcomeMessage();
  }

  void _addWelcomeMessage() {
    ChatMessage welcomeMessage = ChatMessage(
      user: geminiUser,
      createdAt: DateTime.now(),
      text: "Hello! I'm Gemini, your assistant for summarizing PDF files. To upload a PDF for summary, just tap the purple button in the bottom right corner.",
    );

    setState(() {
      messages = [welcomeMessage, ...messages];
    });
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          "PDFSum",
          style: TextStyle(
            color: Colors.white, // Set the title font color to white
          ),
        ),
        backgroundColor: Colors.deepPurple, // Set the AppBar background to deep purple
      ),
      body: _buildUI(),
    );
  }

  Widget _buildUI() {
    return DashChat(
      inputOptions: InputOptions(
        trailing: [
          Container(
            decoration: const BoxDecoration(
              color: Colors.deepPurple, // Choose your desired background color here
              shape: BoxShape.circle, // Make it circular
            ),
            child: IconButton(
              onPressed: _sendPDFMessage,
              icon: const Icon(
                Icons.picture_as_pdf, // Use a PDF-like icon
                color: Colors.white, // Make the icon white for better contrast
              ),
            ),
          )
        ],
      ),
      currentUser: currentUser,
      onSend: _sendMessage,
      messages: messages,
    );
  }

  void _sendMessage(ChatMessage chatMessage) {
    setState(() {
      messages = [chatMessage, ...messages];
    });
    try {
      String userQuestion = chatMessage.text;
      gemini.streamGenerateContent(userQuestion).listen((event) {
        ChatMessage? lastMessage = messages.firstOrNull;
        // Check if the last message is from Gemini, if not, we need to add the last message from Gemini to the list
        if (lastMessage != null && lastMessage.user == geminiUser) {
          lastMessage = messages.removeAt(0);
          String response = event.content?.parts?.fold("", (previous, current) => "$previous${current.text}") ?? "";
          lastMessage.text += response;
          setState(() {
            messages = [lastMessage!, ...messages];
          });
        } else {
          String response = event.content?.parts?.fold("", (previous, current) => "$previous${current.text}") ?? "";
          ChatMessage message = ChatMessage(
            user: geminiUser,
            createdAt: DateTime.now(),
            text: response,
          );
          setState(() {
            messages = [message, ...messages];
          });
        }
      });
    } catch (e) {
      print(e);
    }
  }

  void _sendPDFMessage() async {
    // Show loading dialog while analyzing the PDF
    _showLoadingDialog();

    FilePickerResult? result = await FilePicker.platform.pickFiles();

    if (result != null) {
      File file = File(result.files.single.path!);

      try {
        String pdfText = await _extractTextFromPDF(file);

        if (pdfText.isNotEmpty) {
          // Summarize the PDF content
          String summarizedText = await _summarizePDFText(pdfText);

          // Show the summarized result in the chat
          ChatMessage message = ChatMessage(
            user: geminiUser,
            createdAt: DateTime.now(),
            text: summarizedText,
          );

          setState(() {
            messages = [message, ...messages];
          });
        } else {
          // Show error message if extraction fails
          ChatMessage errorMessage = ChatMessage(
            user: geminiUser,
            createdAt: DateTime.now(),
            text: "Failed to extract text from the PDF.",
          );

          setState(() {
            messages = [errorMessage, ...messages];
          });
        }
      } catch (e) {
        // Handle any errors during PDF analysis
        print("Error during PDF analysis: $e");

        // Show an error message in the chat
        ChatMessage errorMessage = ChatMessage(
          user: geminiUser,
          createdAt: DateTime.now(),
          text: "An error occurred while analyzing the PDF.",
        );

        setState(() {
          messages = [errorMessage, ...messages];
        });
      } finally {
        // Remove the loading dialog after processing, whether successful or not
        Navigator.of(context).pop();
      }
    }
  }

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissing the dialog
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

  Future<String> _extractTextFromPDF(File file) async {
    try {
      // Load the PDF document
      final PdfDocument document = PdfDocument(inputBytes: file.readAsBytesSync());
      String extractedText = "";

      // Iterate through all pages to extract text
      for (int i = 0; i < document.pages.count; i++) {
        extractedText += PdfTextExtractor(document).extractText(startPageIndex: i, endPageIndex: i) ?? "";
      }

      // Dispose the document
      document.dispose();

      return extractedText;
    } catch (e) {
      print("Error extracting text from PDF: $e");
      return "";
    }
  }

  Future<String> _summarizePDFText(String pdfText) async {
    try {
      // Generate a summary using Gemini or your preferred method
      String summary = "";
      await for (var event in gemini.streamGenerateContent("Summarize this PDF:\n$pdfText")) {
        summary += event.content?.parts?.fold("", (previous, current) => "$previous${current.text}") ?? "";
      }
      return summary;
    } catch (e) {
      print("Error summarizing PDF text: $e");
      return "Failed to summarize the PDF.";
    }
  }
}
