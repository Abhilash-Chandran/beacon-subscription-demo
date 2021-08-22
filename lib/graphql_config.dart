import 'package:graphql_flutter/graphql_flutter.dart';

class GraphQLConfig {
  static final HttpLink httpLink = HttpLink(
    "https://beacon.aadibajpai.com/graphql",
  );
  static final AuthLink _authLink =
      AuthLink(getToken: () async => 'Bearer ${const String.fromEnvironment('API_KEY')}');

  // Note the initial payload configuration.
  // here we are attaching the authorization header. Somehow only this works.
  // The appollo server should read this information from the context object.
  // This could probably be handled properly in graphql server of beacon.
  static final WebSocketLink websocketLink = WebSocketLink(
    'ws://beacon.aadibajpai.com/subscriptions',
    config: const SocketClientConfig(
      autoReconnect: true,
      initialPayload: {"Authorization": 'Bearer ${const String.fromEnvironment('API_KEY')}'},
    ),
  );

  GraphQLClient graphQlClient() {
    return GraphQLClient(
      cache: GraphQLCache(),
      link: Link.split(
        (request) => request.isSubscription,
        websocketLink,
        _authLink.concat(httpLink),
      ),
    );
  }
}
