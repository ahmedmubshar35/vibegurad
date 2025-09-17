import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';

import 'unknown_viewmodel.dart';

class UnknownView extends StackedView<UnknownViewModel> {
  const UnknownView({super.key});

  @override
  Widget builder(BuildContext context, UnknownViewModel viewModel, Widget? child) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Page Not Found'),
      ),
      body: const Center(
        child: Text('404 - Page Not Found'),
      ),
    );
  }

  @override
  UnknownViewModel viewModelBuilder(BuildContext context) => UnknownViewModel();
}
