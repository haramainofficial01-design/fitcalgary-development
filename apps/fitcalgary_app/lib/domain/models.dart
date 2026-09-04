typedef Json = Map<String, dynamic>;

String? _string(Json json, String snake, [String? camel]) =>
    (json[snake] ?? (camel == null ? null : json[camel]))?.toString();

int? _int(Json json, String snake, [String? camel]) {
  final value = json[snake] ?? (camel == null ? null : json[camel]);
  return value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');
}

double? _double(Json json, String snake, [String? camel]) {
  final value = json[snake] ?? (camel == null ? null : json[camel]);
  return value is num
      ? value.toDouble()
      : double.tryParse(value?.toString() ?? '');
}

DateTime? _date(Json json, String snake, [String? camel]) =>
    DateTime.tryParse(_string(json, snake, camel) ?? '');

class Gym {
  const Gym({
    required this.id,
    required this.name,
    required this.operatorName,
    required this.city,
    this.slug = '',
    this.area,
    this.address,
    this.lowestOngoingMonthlyCents,
    this.lowestFirstYearMonthlyCents,
    this.pricingComplete = false,
    this.saved = false,
  });

  final String id;
  final String slug;
  final String name;
  final String operatorName;
  final String city;
  final String? area;
  final String? address;
  final int? lowestOngoingMonthlyCents;
  final int? lowestFirstYearMonthlyCents;
  final bool pricingComplete;
  final bool saved;

  factory Gym.fromJson(Json json) => Gym(
    id: _string(json, 'id') ?? '',
    slug: _string(json, 'slug') ?? '',
    name: _string(json, 'name') ?? 'Gym',
    operatorName:
        _string(json, 'operator', 'operatorName') ??
        _string(json, 'operator_name') ??
        'Independent',
    city: _string(json, 'city') ?? 'Calgary',
    area: _string(json, 'area') ?? _string(json, 'neighbourhood'),
    address: _string(json, 'address') ?? _string(json, 'address_line1'),
    lowestOngoingMonthlyCents: _int(
      json,
      'lowest_ongoing_monthly_cents',
      'lowestOngoingMonthlyCents',
    ),
    lowestFirstYearMonthlyCents: _int(
      json,
      'lowest_first_year_monthly_cents',
      'lowestFirstYearMonthlyCents',
    ),
    pricingComplete:
        json['pricing_complete'] == true || json['pricingComplete'] == true,
    saved: json['saved'] == true,
  );
}

class EventListing {
  const EventListing({
    required this.id,
    required this.name,
    required this.startAt,
    this.location,
    this.registrationStatus,
    this.sport,
    this.slug = '',
    this.phase,
    this.description,
    this.organizer,
    this.endAt,
    this.registrationDeadline,
    this.registrationUrl,
    this.entryRequirements,
    this.category,
  });

  final String id;
  final String slug;
  final String name;
  final DateTime? startAt;
  final String? location;
  final String? registrationStatus;
  final String? sport;
  final String? phase;
  final String? description;
  final String? organizer;
  final DateTime? endAt;
  final DateTime? registrationDeadline;
  final String? registrationUrl;
  final String? entryRequirements;
  final String? category;

  factory EventListing.fromJson(Json json) => EventListing(
    id: _string(json, 'id') ?? '',
    slug: _string(json, 'slug') ?? '',
    name: _string(json, 'name') ?? 'Event',
    startAt: _date(json, 'start_at', 'startAt'),
    location: _string(json, 'location') ?? _string(json, 'city'),
    registrationStatus: _string(
      json,
      'registration_status',
      'registrationStatus',
    ),
    sport: _string(json, 'sport'),
    phase: _string(json, 'phase'),
    description: _string(json, 'description'),
    organizer: _string(json, 'organizer'),
    endAt: _date(json, 'end_at', 'endAt'),
    registrationDeadline: _date(
      json,
      'registration_deadline',
      'registrationDeadline',
    ),
    registrationUrl: _string(
      json,
      'external_registration_url',
      'externalRegistrationUrl',
    ),
    entryRequirements: _string(json, 'entry_requirements', 'entryRequirements'),
    category: _string(json, 'category'),
  );
}

class ClubListing {
  const ClubListing({
    required this.id,
    required this.slug,
    required this.name,
    required this.sport,
    this.category,
    this.description,
    this.address,
    this.city,
    this.websiteUrl,
    this.registrationUrl,
    this.eligibility,
    this.seasonInformation,
    this.tags = const [],
  });

  final String id;
  final String slug;
  final String name;
  final String sport;
  final String? category;
  final String? description;
  final String? address;
  final String? city;
  final String? websiteUrl;
  final String? registrationUrl;
  final String? eligibility;
  final String? seasonInformation;
  final List<String> tags;

  factory ClubListing.fromJson(Json json) => ClubListing(
    id: _string(json, 'id') ?? '',
    slug: _string(json, 'slug') ?? '',
    name: _string(json, 'name') ?? 'Club',
    sport: _string(json, 'sport') ?? 'Community',
    category: _string(json, 'category'),
    description: _string(json, 'description'),
    address: _string(json, 'address'),
    city: _string(json, 'city'),
    websiteUrl: _string(json, 'website_url', 'websiteUrl'),
    registrationUrl: _string(json, 'registration_url', 'registrationUrl'),
    eligibility: _string(json, 'eligibility'),
    seasonInformation: _string(json, 'season_information', 'seasonInformation'),
    tags: (json['tags'] as List? ?? const [])
        .map((value) => value.toString())
        .toList(growable: false),
  );
}

class Discipline {
  const Discipline({
    required this.id,
    required this.displayName,
    required this.metricType,
    this.unit,
    this.evidenceType = 'VIDEO',
    this.communityEligible = true,
  });

  final String id;
  final String displayName;
  final String metricType;
  final String? unit;
  final String evidenceType;
  final bool communityEligible;

  factory Discipline.fromJson(Json json) => Discipline(
    id: _string(json, 'id') ?? '',
    displayName: _string(json, 'display_name', 'displayName') ?? 'Discipline',
    metricType: _string(json, 'metric_type', 'metricType') ?? 'POINTS',
    unit: _string(json, 'unit'),
    evidenceType: _string(json, 'evidence_type', 'evidenceType') ?? 'VIDEO',
    communityEligible:
        json['community_eligible'] != false &&
        json['communityEligible'] != false,
  );
}

class SubmissionRecord {
  const SubmissionRecord({
    required this.id,
    required this.discipline,
    required this.claimedMetric,
    required this.status,
    required this.createdAt,
    this.decidedAt,
    this.reviewComment,
  });

  final String id;
  final String discipline;
  final double claimedMetric;
  final String status;
  final DateTime? createdAt;
  final DateTime? decidedAt;
  final String? reviewComment;

  factory SubmissionRecord.fromJson(Json json) {
    final reviews = json['reviews'];
    final last = reviews is List && reviews.isNotEmpty && reviews.last is Json
        ? reviews.last as Json
        : null;
    return SubmissionRecord(
      id: _string(json, 'id') ?? '',
      discipline:
          _string(json, 'discipline') ??
          _string(json, 'display_name', 'displayName') ??
          'Discipline',
      claimedMetric: _double(json, 'claimed_metric', 'claimedMetric') ?? 0,
      status: _string(json, 'status') ?? 'UNKNOWN',
      createdAt: _date(json, 'created_at', 'createdAt'),
      decidedAt: _date(json, 'decided_at', 'decidedAt'),
      reviewComment: last == null
          ? null
          : _string(last, 'comments') ?? _string(last, 'comment'),
    );
  }
}

class AthleteProfile {
  const AthleteProfile({
    required this.id,
    required this.displayName,
    this.bio,
    this.city,
    this.gymName,
    this.roles = const [],
  });

  final String id;
  final String displayName;
  final String? bio;
  final String? city;
  final String? gymName;
  final List<String> roles;

  factory AthleteProfile.fromJson(Json json) => AthleteProfile(
    id: _string(json, 'id') ?? '',
    displayName:
        _string(json, 'display_name', 'displayName') ?? 'FitCalgary athlete',
    bio: _string(json, 'bio'),
    city: _string(json, 'city'),
    gymName:
        _string(json, 'home_gym_name', 'homeGymName') ??
        _string(json, 'gym_name', 'gymName'),
    roles: (json['roles'] as List? ?? const [])
        .map((value) => value.toString())
        .toList(growable: false),
  );
}
