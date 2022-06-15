import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:lotti/classes/config.dart';

ImapConfig? configFromForm(GlobalKey<FormBuilderState> formKey) {
  formKey.currentState!.save();
  if (formKey.currentState!.validate()) {
    final formData = formKey.currentState?.value;

    String getTrimmed(String k) {
      return formData![k].toString().trim();
    }

    return ImapConfig(
      host: getTrimmed('imap_host'),
      // folder: getTrimmed('imap_folder'),
      folder: 'INBOX.lotti-sync',
      userName: getTrimmed('imap_userName'),
      password: getTrimmed('imap_password'),
      port: int.parse(formData!['imap_port'] as String),
    );
  } else {
    return null;
  }
}
