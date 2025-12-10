import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AppNotifications extends StatelessWidget {
  const AppNotifications({super.key});

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      // backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SizedBox(
            height: screenHeight * 0.95, // <-- Force 95% of viewport height
            width: double.infinity,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.8,
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: SvgPicture.string(
                        noNotificationIllustration,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  ErrorInfo(
                    title: "Empty Notifications",
                    description:
                        "It looks like you don't have any notifications right now. We'll let you know when there's something new.",
                    btnText: "Check again",
                    press: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ErrorInfo extends StatelessWidget {
  const ErrorInfo({
    super.key,
    required this.title,
    required this.description,
    this.button,
    this.btnText,
    required this.press,
  });

  final String title;
  final String description;
  final Widget? button;
  final String? btnText;
  final VoidCallback press;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 400),
      alignment: Alignment.center,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .headlineSmall!
                .copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Text(
            description,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 32),
          button ??
              ElevatedButton(
                onPressed: press,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                  ),
                ),
                child: Text(btnText ?? "Retry".toUpperCase()),
              ),
        ],
      ),
    );
  }
}

const noNotificationIllustration = '''
<!-- Your SVG content here -->
''';
