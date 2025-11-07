import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/call.dart';

class CallTile extends StatelessWidget {
  final Call call;

  const CallTile({super.key, required this.call});

  @override
  Widget build(BuildContext context) {
    final isIncoming = call.direction == 'incoming';
    final isOutgoing = call.direction == 'outgoing';
    final isMissed = call.direction == 'missed';

    Color iconColor;
    Color arrowColor;
    IconData callIcon;
    String callTypeText;

    if (isIncoming) {
      iconColor = Colors.green;
      arrowColor = Colors.green;
      callIcon = Icons.call_received;
      callTypeText = 'Incoming';
    } else if (isOutgoing) {
      iconColor = Colors.blue;
      arrowColor = Colors.blue;
      callIcon = Icons.call_made;
      callTypeText = 'Outgoing';
    } else if (isMissed) {
      iconColor = Colors.red;
      arrowColor = Colors.red;
      callIcon = Icons.call_missed;
      callTypeText = 'Missed';
    } else {
      // Fallback for any other call types
      iconColor = Colors.grey;
      arrowColor = Colors.grey;
      callIcon = Icons.call;
      callTypeText = call.direction;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: iconColor,
          child: Icon(
            callIcon,
            color: Colors.white,
          ),
        ),
        title: Text(
          call.phoneNumber,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$callTypeText • ${call.formattedDuration}',
            ),
            Text(
              DateFormat('MMM dd, yyyy • hh:mm a').format(call.startTime),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        trailing: Icon(
          isIncoming ? Icons.arrow_downward : Icons.arrow_upward,
          color: arrowColor,
        ),
      ),
    );
  }
}
