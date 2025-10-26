import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/call_log.dart';
import '../providers/call_log_provider.dart';
import '../providers/contact_provider.dart';

class CallLogsTab extends StatefulWidget {
  const CallLogsTab({super.key});

  @override
  State<CallLogsTab> createState() => _CallLogsTabState();
}

class _CallLogsTabState extends State<CallLogsTab> with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CallLogProvider>().fetchCallLogs(showLoading: false);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot make phone call')),
        );
      }
    }
  }

  Future<void> _sendSMS(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'sms', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot send SMS')),
        );
      }
    }
  }

  String _formatDuration(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes}m ${remainingSeconds}s';
  }

  IconData _getCallTypeIcon(String callType) {
    switch (callType.toLowerCase()) {
      case 'incoming':
        return Icons.call_received;
      case 'outgoing':
        return Icons.call_made;
      case 'missed':
        return Icons.call_missed;
      default:
        return Icons.phone;
    }
  }

  Color _getCallTypeColor(String callType) {
    switch (callType.toLowerCase()) {
      case 'incoming':
        return Colors.blue;
      case 'outgoing':
        return Colors.green;
      case 'missed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search call logs...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            onChanged: (value) {
              setState(() => _searchQuery = value.toLowerCase());
            },
          ),
        ),
        Expanded(
          child: Consumer2<CallLogProvider, ContactProvider>(
            builder: (context, callLogProvider, contactProvider, _) {
              if (callLogProvider.isLoading && callLogProvider.callLogs.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }

              if (callLogProvider.errorMessage != null && callLogProvider.callLogs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Error: ${callLogProvider.errorMessage}', textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => callLogProvider.fetchCallLogs(),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              }

              final filteredCallLogs = _searchQuery.isEmpty
                  ? callLogProvider.callLogs
                  : callLogProvider.callLogs.where((callLog) {
                      final contact = contactProvider.getContactByPhone(callLog.phoneNumber);
                      final contactName = callLog.contactName ?? contact?.name;

                      return (contactName?.toLowerCase().contains(_searchQuery) ?? false) ||
                          callLog.phoneNumber.contains(_searchQuery) ||
                          callLog.callType.toLowerCase().contains(_searchQuery);
                    }).toList();

              if (kDebugMode) {
                print('Number of call logs being displayed: ${filteredCallLogs.length}');
              }

              if (filteredCallLogs.isEmpty) {
                return Center(
                  child: Text(_searchQuery.isEmpty
                      ? 'No call logs yet. Sync your phone to get started!'
                      : 'No call logs found matching "$_searchQuery"'),
                );
              }

              return RefreshIndicator(
                onRefresh: () => callLogProvider.fetchCallLogs(),
                child: ListView.builder(
                  itemCount: filteredCallLogs.length,
                  itemBuilder: (context, index) {
                    final CallLog callLog = filteredCallLogs[index];
                    final contact = contactProvider.getContactByPhone(callLog.phoneNumber);
                    final contactName = callLog.contactName ?? contact?.name;
                    final displayName = contactName ?? callLog.phoneNumber;
                    final dateFormatter = DateFormat('MMM dd, HH:mm');

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _getCallTypeColor(callLog.callType).withAlpha(51),
                          child: Icon(
                            _getCallTypeIcon(callLog.callType),
                            color: _getCallTypeColor(callLog.callType),
                          ),
                        ),
                        title: Text(
                          displayName,
                          style: TextStyle(
                            fontWeight: contactName != null ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (contactName != null)
                              Text(
                                callLog.phoneNumber,
                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                              ),
                            Text(
                              '${callLog.callType.toUpperCase()} • ${_formatDuration(callLog.duration)} • ${dateFormatter.format(callLog.timestamp)}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.phone, color: Colors.green),
                              tooltip: 'Call',
                              onPressed: () => _makePhoneCall(callLog.phoneNumber),
                            ),
                            IconButton(
                              icon: const Icon(Icons.message, color: Colors.blue),
                              tooltip: 'Text',
                              onPressed: () => _sendSMS(callLog.phoneNumber),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
