import 'package:flutter/material.dart';
import '../ticket_detail_screen.dart';

/// Thin shell that renders the shared [TicketDetailScreen] in manager context.
/// The shared screen detects the user's role and adjusts controls accordingly.
class ManagerTicketDetailScreen extends StatelessWidget {
  final String ticketId;

  const ManagerTicketDetailScreen({super.key, required this.ticketId});

  @override
  Widget build(BuildContext context) {
    return TicketDetailScreen(ticketId: ticketId, role: 'manager');
  }
}
