import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/call.dart';

class CallTile extends StatelessWidget {
  final Call call;

  const CallTile({super.key, required this.call});

  @override
  Widget build(BuildContext context) {
    final isIncoming = call.direction == 'incoming';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isIncoming ? Colors.green : Colors.blue,
          child: Icon(
            isIncoming ? Icons.call_received : Icons.call_made,
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
              '${isIncoming ? 'Incoming' : 'Outgoing'} • ${call.formattedDuration}',
            ),
            Text(
              DateFormat('MMM dd, yyyy • hh:mm a').format(call.startTime),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        trailing: Icon(
          isIncoming ? Icons.arrow_downward : Icons.arrow_upward,
          color: isIncoming ? Colors.green : Colors.blue,
        ),
      ),
    );
  }
}
