import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:loan_app_new/providers/auth_provider.dart';
import 'package:loan_app_new/utils/toast_utils.dart';

class Guarantor {
  String fullName;
  String occupation;
  String address;
  String phoneNumber;
  String relationship;

  Guarantor({
    this.fullName = '',
    this.occupation = '',
    this.address = '',
    this.phoneNumber = '',
    this.relationship = '',
  });
}

class GuarantorScreen extends StatefulWidget {
  final int? loanId;

  const GuarantorScreen({super.key, this.loanId});

  @override
  State<GuarantorScreen> createState() => _GuarantorScreenState();
}

class _GuarantorScreenState extends State<GuarantorScreen> {
  List<Guarantor> guarantors = [Guarantor()];
  bool _isSubmitting = false;

  final _supabase = Supabase.instance.client;

  void _addGuarantor() {
    setState(() {
      guarantors.add(Guarantor());
    });
  }

  void _removeGuarantor(int index) {
    setState(() {
      if (guarantors.length > 1) {
        guarantors.removeAt(index);
      }
    });
  }

  bool _validate() {
    for (int i = 0; i < guarantors.length; i++) {
      final g = guarantors[i];
      if (g.fullName.trim().isEmpty) {
        showToast('Guarantor ${i + 1}: Full name is required', isError: true);
        return false;
      }
      if (g.phoneNumber.trim().isEmpty) {
        showToast('Guarantor ${i + 1}: Phone number is required', isError: true);
        return false;
      }
      if (g.phoneNumber.trim().length < 10) {
        showToast('Guarantor ${i + 1}: Enter a valid phone number', isError: true);
        return false;
      }
      if (g.relationship.trim().isEmpty) {
        showToast('Guarantor ${i + 1}: Relationship is required', isError: true);
        return false;
      }
    }
    return true;
  }

  Future<void> _submit() async {
    if (!_validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      // Build one insert payload per guarantor
      final rows = guarantors.map((g) {
        return {
          'user_id': user.id,
          'loan_id': widget.loanId, // null if not attached to a specific loan yet
          'full_name': g.fullName.trim(),
          'occupation': g.occupation.trim(),
          'address': g.address.trim(),
          'phone_number': g.phoneNumber.trim(),
          'relationship': g.relationship.trim(),
          'created_at': DateTime.now().toIso8601String(),
        };
      }).toList();

      await _supabase.from('guarantors').insert(rows);

      if (!mounted) return;
      showToast('Guarantors saved successfully!');
      Navigator.pop(context, true); // return true so callers can refresh
    } catch (e) {
      if (!mounted) return;
      showToast('Failed to save guarantors: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Guarantor's Details"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: guarantors.length,
                itemBuilder: (context, index) {
                  return GuarantorForm(
                    key: ValueKey(index),
                    guarantor: guarantors[index],
                    onRemove: () => _removeGuarantor(index),
                    showRemoveButton: guarantors.length > 1,
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isSubmitting ? null : _addGuarantor,
                icon: const Icon(Icons.add),
                label: const Text('Add Another Guarantor'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _submit,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.check),
                label: Text(_isSubmitting ? 'Saving...' : 'Submit'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GuarantorForm extends StatelessWidget {
  final Guarantor guarantor;
  final VoidCallback onRemove;
  final bool showRemoveButton;

  const GuarantorForm({
    super.key,
    required this.guarantor,
    required this.onRemove,
    this.showRemoveButton = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showRemoveButton)
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: const Icon(Icons.remove_circle, color: Colors.red),
                  onPressed: onRemove,
                ),
              ),
            TextFormField(
              initialValue: guarantor.fullName,
              onChanged: (value) => guarantor.fullName = value,
              decoration: const InputDecoration(labelText: 'Full Name'),
            ),
            TextFormField(
              initialValue: guarantor.occupation,
              onChanged: (value) => guarantor.occupation = value,
              decoration: const InputDecoration(labelText: 'Occupation'),
            ),
            TextFormField(
              initialValue: guarantor.address,
              onChanged: (value) => guarantor.address = value,
              decoration: const InputDecoration(labelText: 'Address'),
            ),
            TextFormField(
              initialValue: guarantor.phoneNumber,
              onChanged: (value) => guarantor.phoneNumber = value,
              decoration: const InputDecoration(labelText: 'Phone Number'),
              keyboardType: TextInputType.phone,
            ),
            TextFormField(
              initialValue: guarantor.relationship,
              onChanged: (value) => guarantor.relationship = value,
              decoration: const InputDecoration(labelText: 'Relationship'),
            ),
          ],
        ),
      ),
    );
  }
}