import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/dose.dart';
import '../../services/database_service.dart';
import '../../providers/app_providers.dart';

class AddEditDoseScreen extends ConsumerStatefulWidget {
  final Dose? dose;

  const AddEditDoseScreen({super.key, this.dose});

  @override
  ConsumerState<AddEditDoseScreen> createState() => _AddEditDoseScreenState();
}

class _AddEditDoseScreenState extends ConsumerState<AddEditDoseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _countController = TextEditingController();
  final _conditionsController = TextEditingController();

  int _selectedChamber = 0;
  DateTime _selectedTime = DateTime.now();
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 30));
  bool _isLoading = false;

  bool get _isEditing => widget.dose != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _loadDoseData();
    } else {
      // Set default values for new dose
      _countController.text = '1';
      _selectedTime = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
        9, // 9 AM default
        0,
      );
    }
  }

  void _loadDoseData() {
    final dose = widget.dose!;
    _nameController.text = dose.name;
    _selectedChamber = dose.chamber;
    _selectedTime = dose.time;
    _startDate = dose.startDate;
    _endDate = dose.endDate;
    _countController.text = dose.count.toString();
    _conditionsController.text = dose.conditions ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _countController.dispose();
    _conditionsController.dispose();
    super.dispose();
  }

  Future<void> _saveDose() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final dose = Dose(
        id: _isEditing ? widget.dose!.id : '',
        name: _nameController.text.trim(),
        chamber: _selectedChamber,
        time: _selectedTime,
        startDate: _startDate,
        endDate: _endDate,
        count: int.parse(_countController.text),
        conditions: _conditionsController.text.trim().isEmpty 
            ? null 
            : _conditionsController.text.trim(),
        status: _isEditing ? widget.dose!.status : DoseStatus.upcoming,
        takenAt: _isEditing ? widget.dose!.takenAt : null,
      );

      final databaseService = ref.read(databaseServiceProvider);
      await databaseService.addOrUpdateDose(dose);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing 
                ? 'Medication updated successfully' 
                : 'Medication added successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _selectTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedTime),
    );

    if (time != null) {
      setState(() {
        _selectedTime = DateTime(
          _selectedTime.year,
          _selectedTime.month,
          _selectedTime.day,
          time.hour,
          time.minute,
        );
      });
    }
  }

  Future<void> _selectStartDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null) {
      setState(() {
        _startDate = date;
        // Ensure end date is not before start date
        if (_endDate.isBefore(_startDate)) {
          _endDate = _startDate.add(const Duration(days: 30));
        }
      });
    }
  }

  Future<void> _selectEndDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null) {
      setState(() {
        _endDate = date;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Medication' : 'Add Medication'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          if (!_isLoading)
            TextButton(
              onPressed: _saveDose,
              child: Text(
                'Save',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Medicine name
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Medication Details',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _nameController,
                        textInputAction: TextInputAction.next,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Medicine Name',
                          prefixIcon: Icon(Icons.medication),
                          hintText: 'e.g., Aspirin, Vitamin D',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter the medicine name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int>(
                        value: _selectedChamber,
                        decoration: const InputDecoration(
                          labelText: 'Chamber',
                          prefixIcon: Icon(Icons.inventory_2),
                        ),
                        items: [0, 1, 2, 3]
                            .map((chamber) => DropdownMenuItem(
                                  value: chamber,
                                  child: Text('Chamber ${['A', 'B', 'C', 'D'][chamber]}'),
                                ))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _selectedChamber = value;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _countController,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Number of Pills',
                          prefixIcon: Icon(Icons.control_point),
                          suffixText: 'pills',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter the number of pills';
                          }
                          final count = int.tryParse(value.trim());
                          if (count == null || count <= 0) {
                            return 'Please enter a valid number';
                          }
                          if (count > 10) {
                            return 'Maximum 10 pills per dose';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Schedule
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Schedule',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Time picker
                      InkWell(
                        onTap: _selectTime,
                        borderRadius: BorderRadius.circular(8),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Time',
                            prefixIcon: Icon(Icons.access_time),
                          ),
                          child: Text(
                            DateFormat('HH:mm').format(_selectedTime),
                            style: theme.textTheme.bodyLarge,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Start date picker
                      InkWell(
                        onTap: _selectStartDate,
                        borderRadius: BorderRadius.circular(8),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Start Date',
                            prefixIcon: Icon(Icons.calendar_today),
                          ),
                          child: Text(
                            DateFormat('MMM dd, yyyy').format(_startDate),
                            style: theme.textTheme.bodyLarge,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // End date picker
                      InkWell(
                        onTap: _selectEndDate,
                        borderRadius: BorderRadius.circular(8),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'End Date',
                            prefixIcon: Icon(Icons.event),
                          ),
                          child: Text(
                            DateFormat('MMM dd, yyyy').format(_endDate),
                            style: theme.textTheme.bodyLarge,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Special conditions
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Special Instructions (Optional)',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _conditionsController,
                        maxLines: 3,
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(
                          labelText: 'Special Conditions or Instructions',
                          prefixIcon: Icon(Icons.note),
                          hintText: 'e.g., Take with food, Before bedtime',
                          alignLabelWithHint: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Save button
              ElevatedButton(
                onPressed: _isLoading ? null : _saveDose,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(_isEditing ? 'Update Medication' : 'Add Medication'),
              ),

              // Delete button (only for editing)
              if (_isEditing) ...[
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: _isLoading ? null : _showDeleteDialog,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Delete Medication'),
                ),
              ],

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Medication'),
        content: Text('Are you sure you want to delete "${widget.dose!.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop(); // Close dialog
              
              setState(() => _isLoading = true);
              
              try {
                final databaseService = ref.read(databaseServiceProvider);
                await databaseService.deleteDose(widget.dose!.id);
                
                if (mounted) {
                  Navigator.of(context).pop(); // Close screen
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Medication deleted successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error deleting medication: $e'),
                      backgroundColor: Theme.of(context).colorScheme.error,
                    ),
                  );
                }
              } finally {
                if (mounted) {
                  setState(() => _isLoading = false);
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
