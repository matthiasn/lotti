import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:lotti/classes/config.dart';

String getTrimmed(Map<String, dynamic>? formData, String k) {
  if (formData == null || formData[k] == null) {
    return '';
  }

  return formData[k].toString().trim();
}

int getPort(Map<String, dynamic>? formData) {
  return int.parse(getTrimmed(formData, 'imap_port'));
}

ImapConfig? configFromForm(GlobalKey<FormBuilderState> formKey) {
  formKey.currentState!.save();
  if (formKey.currentState!.validate()) {
    final formData = formKey.currentState?.value;

    return ImapConfig(
      host: getTrimmed(formData, 'imap_host'),
      // folder: getTrimmed('imap_folder'),
      folder: 'INBOX.lotti-sync',
      userName: getTrimmed(formData, 'imap_userName'),
      password: getTrimmed(formData, 'imap_password'),
      port: getPort(formData),
    );
  } else {
    return null;
  }
}
