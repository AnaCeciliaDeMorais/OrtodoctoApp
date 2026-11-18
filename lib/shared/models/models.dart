import 'package:flutter/material.dart';

import '../../core/formatters.dart';

enum UserRole {
  owner('Chefe'),
  staff('Funcionário'),
  client('Cliente');

  const UserRole(this.label);
  final String label;

  static UserRole parse(String? v) =>
      UserRole.values.firstWhere((r) => r.name == v, orElse: () => UserRole.client);
}

double _num(dynamic v) => v == null ? 0 : (v as num).toDouble();

class Profile {
  Profile({
    required this.id,
    required this.role,
    required this.fullName,
    this.email,
    this.phone,
    this.companyId,
    this.active = true,
  });

  final String id;
  final UserRole role;
  final String fullName;
  final String? email;
  final String? phone;
  final String? companyId;
  final bool active;

  factory Profile.fromMap(Map<String, dynamic> m) => Profile(
        id: m['id'] as String,
        role: UserRole.parse(m['role'] as String?),
        fullName: (m['full_name'] as String?) ?? '',
        email: m['email'] as String?,
        phone: m['phone'] as String?,
        companyId: m['company_id'] as String?,
        active: (m['active'] as bool?) ?? true,
      );

  String get firstName => fullName.trim().split(' ').first;
}

class Company {
  Company({
    required this.id,
    required this.ownerId,
    required this.name,
    this.cnpj,
    this.phone,
    this.email,
    this.address,
    this.openingTime = '08:00',
    this.closingTime = '18:00',
    this.slotMinutes = 30,
    this.maxPerSlot = 2,
    this.active = true,
  });

  final String id;
  final String ownerId;
  final String name;
  final String? cnpj;
  final String? phone;
  final String? email;
  final String? address;
  final String openingTime;
  final String closingTime;
  final int slotMinutes;
  final int maxPerSlot;
  final bool active;

  factory Company.fromMap(Map<String, dynamic> m) => Company(
        id: m['id'] as String,
        ownerId: m['owner_id'] as String,
        name: m['name'] as String,
        cnpj: m['cnpj'] as String?,
        phone: m['phone'] as String?,
        email: m['email'] as String?,
        address: m['address'] as String?,
        openingTime: timeOfDb((m['opening_time'] as String?) ?? '08:00'),
        closingTime: timeOfDb((m['closing_time'] as String?) ?? '18:00'),
        slotMinutes: (m['slot_minutes'] as int?) ?? 30,
        maxPerSlot: (m['max_per_slot'] as int?) ?? 2,
        active: (m['active'] as bool?) ?? true,
      );
}

class ClinicDay {
  ClinicDay({
    required this.id,
    required this.companyId,
    required this.day,
    required this.startTime,
    required this.endTime,
    this.breakStart,
    this.breakEnd,
    this.notes,
  });

  final String id;
  final String companyId;
  final DateTime day;
  final String startTime;
  final String endTime;
  final String? breakStart;
  final String? breakEnd;
  final String? notes;

  factory ClinicDay.fromMap(Map<String, dynamic> m) => ClinicDay(
        id: m['id'] as String,
        companyId: m['company_id'] as String,
        day: DateTime.parse(m['day'] as String),
        startTime: timeOfDb(m['start_time'] as String),
        endTime: timeOfDb(m['end_time'] as String),
        breakStart: m['break_start'] == null ? null : timeOfDb(m['break_start'] as String),
        breakEnd: m['break_end'] == null ? null : timeOfDb(m['break_end'] as String),
        notes: m['notes'] as String?,
      );

  String get hoursLabel {
    final pause = breakStart == null ? '' : ' (pausa $breakStart–$breakEnd)';
    return '$startTime–$endTime$pause';
  }
}

class Patient {
  Patient({
    required this.id,
    required this.companyId,
    required this.fullName,
    this.userId,
    this.cpf,
    this.birthDate,
    this.phone,
    this.email,
    this.guardianName,
    this.guardianCpf,
    this.address,
    this.notes,
    this.active = true,
  });

  final String id;
  final String companyId;
  final String fullName;
  final String? userId;
  final String? cpf;
  final DateTime? birthDate;
  final String? phone;
  final String? email;
  final String? guardianName;
  final String? guardianCpf;
  final String? address;
  final String? notes;
  final bool active;

  factory Patient.fromMap(Map<String, dynamic> m) => Patient(
        id: m['id'] as String,
        companyId: m['company_id'] as String,
        fullName: m['full_name'] as String,
        userId: m['user_id'] as String?,
        cpf: m['cpf'] as String?,
        birthDate: parseDate(m['birth_date']),
        phone: m['phone'] as String?,
        email: m['email'] as String?,
        guardianName: m['guardian_name'] as String?,
        guardianCpf: m['guardian_cpf'] as String?,
        address: m['address'] as String?,
        notes: m['notes'] as String?,
        active: (m['active'] as bool?) ?? true,
      );

  Map<String, dynamic> toMap() => {
        'company_id': companyId,
        'full_name': fullName.trim(),
        'cpf': _nullIfEmpty(onlyDigits(cpf)),
        'birth_date': birthDate == null ? null : isoDate(birthDate!),
        'phone': _nullIfEmpty(onlyDigits(phone)),
        'email': _nullIfEmpty(email?.trim()),
        'guardian_name': _nullIfEmpty(guardianName?.trim()),
        'guardian_cpf': _nullIfEmpty(onlyDigits(guardianCpf)),
        'address': _nullIfEmpty(address?.trim()),
        'notes': _nullIfEmpty(notes?.trim()),
        'active': active,
      };

  bool get hasAccess => userId != null;
}

String? _nullIfEmpty(String? s) => (s == null || s.isEmpty) ? null : s;

enum AppointmentStatus {
  scheduled('Agendado', Colors.blue),
  confirmed('Confirmado', Colors.teal),
  done('Atendido', Colors.green),
  missed('Faltou', Colors.orange),
  canceled('Cancelado', Colors.grey);

  const AppointmentStatus(this.label, this.color);
  final String label;
  final Color color;

  static AppointmentStatus parse(String? v) => AppointmentStatus.values
      .firstWhere((s) => s.name == v, orElse: () => AppointmentStatus.scheduled);
}

const appointmentLabels = ['Consulta', 'Avaliação', 'Manutenção', 'Retorno', 'Urgência', 'Procedimento'];

class Appointment {
  Appointment({
    required this.id,
    required this.companyId,
    required this.patientId,
    required this.startsAt,
    this.durationMinutes = 30,
    this.status = AppointmentStatus.scheduled,
    this.label,
    this.notes,
    this.patientName,
    this.patientPhone,
    this.companyName,
  });

  final String id;
  final String companyId;
  final String patientId;
  final DateTime startsAt;
  final int durationMinutes;
  final AppointmentStatus status;
  final String? label;
  final String? notes;
  final String? patientName;
  final String? patientPhone;
  final String? companyName;

  factory Appointment.fromMap(Map<String, dynamic> m) {
    final p = m['patients'] as Map<String, dynamic>?;
    final c = m['companies'] as Map<String, dynamic>?;
    return Appointment(
      id: m['id'] as String,
      companyId: m['company_id'] as String,
      patientId: m['patient_id'] as String,
      startsAt: DateTime.parse(m['starts_at'] as String).toLocal(),
      durationMinutes: (m['duration_minutes'] as int?) ?? 30,
      status: AppointmentStatus.parse(m['status'] as String?),
      label: m['label'] as String?,
      notes: m['notes'] as String?,
      patientName: p?['full_name'] as String?,
      patientPhone: p?['phone'] as String?,
      companyName: c?['name'] as String?,
    );
  }

  bool get isActive => status != AppointmentStatus.canceled;
}

enum ChargeStatus {
  open('Em aberto'),
  paid('Pago'),
  canceled('Cancelado');

  const ChargeStatus(this.label);
  final String label;

  static ChargeStatus parse(String? v) =>
      ChargeStatus.values.firstWhere((s) => s.name == v, orElse: () => ChargeStatus.open);
}

const paymentMethods = [
  'Pix',
  'Dinheiro',
  'Cartão de crédito',
  'Cartão de débito',
  'Boleto',
  'Depósito',
  'Transferência',
];

/// Forma de pagamento que pede o número de parcelas.
const creditCardMethod = 'Cartão de crédito';

/// Um pagamento recebido de uma cobrança. Uma cobrança pode ter vários
/// (várias formas e/ou pagamento parcial).
class ChargePayment {
  ChargePayment({
    required this.id,
    required this.method,
    required this.amount,
    required this.paidOn,
    this.installments = 1,
    this.interest = 0,
    this.receivedBy,
  });

  final String id;
  final String method;
  final double amount;
  final DateTime paidOn;
  final int installments;
  final double interest;
  final String? receivedBy;

  factory ChargePayment.fromMap(Map<String, dynamic> m) => ChargePayment(
        id: m['id'] as String,
        method: m['method'] as String,
        amount: _num(m['amount']),
        paidOn: DateTime.parse(m['paid_on'] as String),
        installments: (m['installments'] as int?) ?? 1,
        interest: _num(m['interest']),
        receivedBy: m['received_by'] as String?,
      );

  String get label => installments > 1 ? '$method ${installments}x' : method;
}

class Charge {
  Charge({
    required this.id,
    required this.companyId,
    required this.patientId,
    required this.description,
    required this.amount,
    required this.dueDate,
    required this.status,
    this.installmentNumber,
    this.installmentTotal,
    this.paidAt,
    this.paymentMethod,
    this.receivedBy,
    this.receivedByName,
    this.approvedBy,
    this.approvedByName,
    this.approvedAt,
    this.files = const [],
    this.payments = const [],
    this.patientName,
    this.companyName,
  });

  final String id;
  final String companyId;
  final String patientId;
  final String description;
  final double amount;
  final DateTime dueDate;
  final ChargeStatus status;
  final int? installmentNumber;
  final int? installmentTotal;
  final DateTime? paidAt;
  final String? paymentMethod;
  final String? receivedBy;
  final String? receivedByName;
  final String? approvedBy;
  final String? approvedByName;
  final DateTime? approvedAt;
  /// Boletos (arquivos) anexados a esta cobrança na pasta do paciente.
  final List<PatientFile> files;
  /// Pagamentos recebidos (vários se foi em mais de uma forma ou parcial).
  final List<ChargePayment> payments;
  final String? patientName;
  final String? companyName;

  factory Charge.fromMap(Map<String, dynamic> m) => Charge(
        id: m['id'] as String,
        companyId: m['company_id'] as String,
        patientId: m['patient_id'] as String,
        description: m['description'] as String,
        amount: _num(m['amount']),
        dueDate: DateTime.parse(m['due_date'] as String),
        status: ChargeStatus.parse(m['status'] as String?),
        installmentNumber: m['installment_number'] as int?,
        installmentTotal: m['installment_total'] as int?,
        paidAt: parseDate(m['paid_at']),
        paymentMethod: m['payment_method'] as String?,
        receivedBy: m['received_by'] as String?,
        receivedByName: (m['receiver'] as Map<String, dynamic>?)?['full_name'] as String?,
        approvedBy: m['approved_by'] as String?,
        approvedByName: (m['approver'] as Map<String, dynamic>?)?['full_name'] as String?,
        approvedAt: m['approved_at'] == null ? null : DateTime.parse(m['approved_at'] as String).toLocal(),
        files: [
          for (final f in (m['patient_files'] as List?) ?? const [])
            PatientFile.fromMap(f as Map<String, dynamic>),
        ],
        payments: [
          for (final p in (m['charge_payments'] as List?) ?? const [])
            ChargePayment.fromMap(p as Map<String, dynamic>),
        ]..sort((a, b) => a.paidOn.compareTo(b.paidOn)),
        patientName: (m['patients'] as Map<String, dynamic>?)?['full_name'] as String?,
        companyName: (m['companies'] as Map<String, dynamic>?)?['name'] as String?,
      );

  bool get isOverdue => status == ChargeStatus.open && dueDate.isBefore(dayOnly(DateTime.now()));
  bool get hasBoleto => files.isNotEmpty;

  /// Quanto já foi pago (sem juros). Cobranças antigas sem a lista de
  /// pagamentos contam o valor todo quando estão pagas.
  double get paidAmount {
    if (payments.isEmpty) return status == ChargeStatus.paid ? amount : 0;
    return payments.fold<double>(0, (a, p) => a + p.amount);
  }

  /// Quanto falta pagar (0 se paga ou cancelada).
  double get remaining {
    if (status != ChargeStatus.open) return 0;
    final r = amount - paidAmount;
    return r < 0.005 ? 0 : double.parse(r.toStringAsFixed(2));
  }

  bool get hasPayments => payments.isNotEmpty || status == ChargeStatus.paid;
  bool get isPartial => status == ChargeStatus.open && payments.isNotEmpty;
  bool get pendingApproval => status == ChargeStatus.paid && approvedBy == null;
  bool get twoStepApproved =>
      status == ChargeStatus.paid && approvedBy != null && approvedBy != receivedBy;

  String get statusLabel => isOverdue
      ? (isPartial ? 'Vencido (parcial)' : 'Vencido')
      : (isPartial ? 'Pago em parte' : status.label);

  Color statusColor(BuildContext context) {
    if (isOverdue) return Theme.of(context).colorScheme.error;
    return switch (status) {
      ChargeStatus.open => Colors.orange.shade800,
      ChargeStatus.paid => Colors.green.shade700,
      ChargeStatus.canceled => Colors.grey,
    };
  }
}

enum CashKind { in_, out }

class CashEntry {
  CashEntry({
    required this.id,
    required this.companyId,
    required this.staffId,
    required this.kind,
    required this.amount,
    required this.description,
    required this.occurredOn,
    this.paymentMethod,
    this.chargeId,
    this.staffName,
    this.companyName,
    this.patientName,
  });

  final String id;
  final String companyId;
  final String staffId;
  final CashKind kind;
  final double amount;
  final String description;
  final DateTime occurredOn;
  final String? paymentMethod;
  final String? chargeId;
  final String? staffName;
  final String? companyName;
  final String? patientName;

  factory CashEntry.fromMap(Map<String, dynamic> m) => CashEntry(
        id: m['id'] as String,
        companyId: m['company_id'] as String,
        staffId: m['staff_id'] as String,
        kind: m['kind'] == 'out' ? CashKind.out : CashKind.in_,
        amount: _num(m['amount']),
        description: m['description'] as String,
        occurredOn: DateTime.parse(m['occurred_on'] as String),
        paymentMethod: m['payment_method'] as String?,
        chargeId: m['charge_id'] as String?,
        staffName: (m['profiles'] as Map<String, dynamic>?)?['full_name'] as String?,
        companyName: (m['companies'] as Map<String, dynamic>?)?['name'] as String?,
        patientName: (m['patients'] as Map<String, dynamic>?)?['full_name'] as String?,
      );

  bool get isIn => kind == CashKind.in_;
  double get signed => isIn ? amount : -amount;
  bool get fromCharge => chargeId != null;
}

class Product {
  Product({
    required this.id,
    required this.companyId,
    required this.name,
    this.description,
    this.category,
    this.price = 0,
    this.promoPrice,
    this.promoUntil,
    this.isPromotion = false,
    this.featured = false,
    this.imageUrl,
    this.imagePath,
    this.active = true,
  });

  final String id;
  final String companyId;
  final String name;
  final String? description;
  final String? category;
  final double price;
  final double? promoPrice;
  final DateTime? promoUntil;
  final bool isPromotion;
  final bool featured;
  final String? imageUrl;
  final String? imagePath;
  final bool active;

  factory Product.fromMap(Map<String, dynamic> m) => Product(
        id: m['id'] as String,
        companyId: m['company_id'] as String,
        name: m['name'] as String,
        description: m['description'] as String?,
        category: m['category'] as String?,
        price: _num(m['price']),
        promoPrice: m['promo_price'] == null ? null : _num(m['promo_price']),
        promoUntil: parseDate(m['promo_until']),
        isPromotion: (m['is_promotion'] as bool?) ?? false,
        featured: (m['featured'] as bool?) ?? false,
        imageUrl: m['image_url'] as String?,
        imagePath: m['image_path'] as String?,
        active: (m['active'] as bool?) ?? true,
      );

  /// Promoção vale enquanto marcada e dentro da data limite (se houver).
  bool get onPromotion =>
      isPromotion && (promoUntil == null || !promoUntil!.isBefore(dayOnly(DateTime.now())));

  double get currentPrice => onPromotion && promoPrice != null ? promoPrice! : price;

  int? get discountPercent {
    if (!onPromotion || promoPrice == null || price <= 0 || promoPrice! >= price) return null;
    return (((price - promoPrice!) / price) * 100).round();
  }

  /// Ordem da vitrine: fixados, depois promoções, depois o resto por nome.
  static int showcaseOrder(Product a, Product b) {
    int rank(Product p) => p.featured ? 0 : (p.onPromotion ? 1 : 2);
    final r = rank(a).compareTo(rank(b));
    return r != 0 ? r : a.name.toLowerCase().compareTo(b.name.toLowerCase());
  }
}

class Question {
  Question({
    required this.id,
    required this.companyId,
    required this.patientId,
    required this.message,
    required this.createdAt,
    this.answer,
    this.answeredAt,
    this.patientName,
    this.companyName,
  });

  final String id;
  final String companyId;
  final String patientId;
  final String message;
  final DateTime createdAt;
  final String? answer;
  final DateTime? answeredAt;
  final String? patientName;
  final String? companyName;

  factory Question.fromMap(Map<String, dynamic> m) => Question(
        id: m['id'] as String,
        companyId: m['company_id'] as String,
        patientId: m['patient_id'] as String,
        message: m['message'] as String,
        createdAt: DateTime.parse(m['created_at'] as String).toLocal(),
        answer: m['answer'] as String?,
        answeredAt: m['answered_at'] == null ? null : DateTime.parse(m['answered_at'] as String).toLocal(),
        patientName: (m['patients'] as Map<String, dynamic>?)?['full_name'] as String?,
        companyName: (m['companies'] as Map<String, dynamic>?)?['name'] as String?,
      );

  bool get answered => answer != null && answer!.trim().isNotEmpty;
}

/// Arquivo na pasta do paciente (boleto ou outro documento).
class PatientFile {
  PatientFile({
    required this.id,
    required this.companyId,
    required this.patientId,
    required this.title,
    required this.filePath,
    required this.fileName,
    required this.createdAt,
    this.chargeId,
    this.kind = 'boleto',
    this.dueDate,
    this.contentType,
    this.sizeBytes,
  });

  final String id;
  final String companyId;
  final String patientId;
  final String? chargeId;
  final String kind;
  final String title;
  final DateTime? dueDate;
  final String filePath;
  final String fileName;
  final String? contentType;
  final int? sizeBytes;
  final DateTime createdAt;

  factory PatientFile.fromMap(Map<String, dynamic> m) => PatientFile(
        id: m['id'] as String,
        companyId: m['company_id'] as String,
        patientId: m['patient_id'] as String,
        chargeId: m['charge_id'] as String?,
        kind: (m['kind'] as String?) ?? 'boleto',
        title: m['title'] as String,
        dueDate: parseDate(m['due_date']),
        filePath: m['file_path'] as String,
        fileName: m['file_name'] as String,
        contentType: m['content_type'] as String?,
        sizeBytes: (m['size_bytes'] as num?)?.toInt(),
        createdAt: DateTime.parse(m['created_at'] as String).toLocal(),
      );

  bool get isBoleto => kind == 'boleto';
  bool get isPdf => (contentType ?? '').contains('pdf') || fileName.toLowerCase().endsWith('.pdf');
}
