import 'package:flutter/material.dart';

/// Spinner centrado y de tamaño visible para usar en toda pantalla que
/// carga una lista — reemplaza los `CircularProgressIndicator` sueltos que
/// quedaban chicos y descentrados en algunas pantallas.
class LoadingIndicator extends StatelessWidget {
  final EdgeInsetsGeometry padding;

  const LoadingIndicator({super.key, this.padding = const EdgeInsets.all(24)});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: padding,
        child: const CircularProgressIndicator(),
      ),
    );
  }
}
