import 'package:graphql_flutter/graphql_flutter.dart';

class GraphQLConfig {
  static final HttpLink httpLink = HttpLink(
    "https://graphql-compose.herokuapp.com/northwind",
  );

  static final WebSocketLink websocketLink = WebSocketLink(
    'wss://graphql-compose.herokuapp.com/northwind',
    config: const SocketClientConfig(
      autoReconnect: true,
    ),
  );

  GraphQLClient graphQlClient() {
    return GraphQLClient(
      cache: GraphQLCache(),
      link: Link.split(
          (request) => request.isSubscription, websocketLink, httpLink),
    );
  }
}
