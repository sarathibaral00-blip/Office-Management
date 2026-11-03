import 'package:equatable/equatable.dart';

class MyProfile extends Equatable {
  const MyProfile(
    this.id,
    this.name,
    this.code,
    this.email,
    this.phone,
    this.photoUrl,
  );
  final String id, name, code, email;
  final String? phone, photoUrl;
  @override
  List<Object?> get props => [id, name, code, email, phone, photoUrl];
}
