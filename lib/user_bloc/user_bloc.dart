import 'dart:async';

import 'package:find_room/bloc/bloc_provider.dart';
import 'package:find_room/data/user/firebase_user_repository.dart';
import 'package:find_room/models/user_entity.dart';
import 'package:find_room/user_bloc/user_login_state.dart';
import 'package:rxdart/rxdart.dart';

class UserBloc implements BaseBloc {
  ///
  /// Sinks
  ///
  final Sink<void> signOut;

  ///
  /// Streams
  ///
  final ValueObservable<UserLoginState> userLoginState$;
  final Stream<UserMessage> message$;

  ///Cleanup
  final void Function() _dispose;

  factory UserBloc(FirebaseUserRepository userRepository) {
    final signOutController = PublishSubject<void>(sync: true);

    final user$ = Observable(userRepository.user())
        .map(_toLoginState)
        .distinct()
        .publishValueSeeded(const NotLogin());

    final signOutMessage$ = signOutController.exhaustMap((_) {
      return Observable.fromFuture(userRepository.signOut())
          .doOnError((e) => print('[DEBUG] logout error=$e'))
          .onErrorReturnWith((e) => UserLogoutMessageError(e))
          .map((_) => const UserLogoutMessageSuccess());
    }).publish();

    final subscriptions = <StreamSubscription<dynamic>>[
      user$.connect(),
      signOutMessage$.connect(),
    ];

    return UserBloc._(
      () {
        signOutController.close();
        subscriptions.forEach((subscription) => subscription.cancel());
      },
      user$,
      signOutController.sink,
      signOutMessage$,
    );
  }

  UserBloc._(
    this._dispose,
    this.userLoginState$,
    this.signOut,
    this.message$,
  );

  @override
  void dispose() => _dispose();

  static UserLoginState _toLoginState(UserEntity userEntity) {
    if (userEntity == null) {
      return const NotLogin();
    }
    return UserLogin(
      avatar: userEntity.avatar,
      fullName: userEntity.fullName,
      email: userEntity.email,
      uid: userEntity.id,
    );
  }
}
