import 'package:bot_toast/bot_toast.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pixez/watercolor/mingcute.dart';

class Toaster {
  static downloadOk(String text) {
    BotToast.showCustomText(
      onlyOne: true,
      duration: Duration(seconds: 1),
      toastBuilder: (textCancel) => Align(
        alignment: Alignment(0, 0.8),
        child: Card(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.0),
                child: WcIcon(Icons.check_circle, color: Colors.green),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8.0,
                  vertical: 8.0,
                ),
                child: Text(text),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static showText(String text) {}
}
