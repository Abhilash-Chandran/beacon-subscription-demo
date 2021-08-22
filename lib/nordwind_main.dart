import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:nordwind/nordwind_graphql_config.dart';
import 'package:rxdart/rxdart.dart';
import 'dart:math';

import 'package:mock_data/mock_data.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter graphql subscription Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const GraphqlSubscriber(),
    );
  }
}

class GraphqlSubscriber extends StatefulWidget {
  const GraphqlSubscriber({Key? key}) : super(key: key);

  @override
  State<GraphqlSubscriber> createState() => _GraphqlSubscriberState();
}

class _GraphqlSubscriberState extends State<GraphqlSubscriber> {
  // Initialize a single graphql config instance. Better to register in a service
  // locator or provide through provider or inherited widget.
  late final GraphQLConfig graphQLConfig;
  late final GraphQLClient graphQlClient;

  // Set of stream objects.
  late final Stream orderCreatedStream;
  late final Stream orderUpdatedStream;
  late final Stream mergedStream;

  // Gql for oreder created subscription.
  final orderCreatedGql = gql(r'''
    subscription{
      orderCreated{
        orderID
        customerID
      }
    }
  ''');

  // Gql for oreder updated subscription.
  final orderUpdatedGql = gql(r'''
    subscription{
      orderUpdated{
        orderID
        customerID
      }
    }
  ''');

  // simply in memory array to hold the order id's
  List<String> orderIds = [];

  Future<void> createDummyOrder() async {
    final createOrderGql = gql(r'''
        mutation CreateOrder($shipNamePar: String, $orderId: Float){
          createOrder(record:{orderID: $orderId, shipName: $shipNamePar}){
            recordId
            record{
              shipName
            }
          }
        }
      ''');
    MutationOptions mutationOptions = MutationOptions(
      document: createOrderGql,
      variables: <String, dynamic>{
        'shipNamePar': mockName(),
        'orderId': Random().nextDouble(),
      },
    );

    final mutationResutls = await graphQlClient.mutate(mutationOptions);
    print(mutationResutls);
    final newRecordId =
        mutationResutls.data?['createOrder']['recordId'] as String;
    orderIds.add(newRecordId);
  }

  Future<void> updateDummyOrder(String recordId) async {
    final updateOrderGql = gql(r'''
        mutation UpdateOrder($recordId: MongoID!, $shipNamePar: String, $orderId: Float){
          action: updateOrder(_id: $recordId, record: {orderID: $orderId, shipName: $shipNamePar}){
            recordId
            record{
              shipName
            }
          }
        }
      ''');
    MutationOptions mutationOptions = MutationOptions(
      document: updateOrderGql,
      variables: <String, dynamic>{
        'recordId': recordId,
        'shipNamePar': mockName(),
        'orderId': Random().nextDouble(),
      },
    );

    final mutationResutls = await graphQlClient.mutate(mutationOptions);
    print('Updated recordid is ===> $mutationResutls');
  }

  @override
  void initState() {
    super.initState();

    // Initialize graphql config and websocket client.
    graphQLConfig = GraphQLConfig();
    graphQlClient = graphQLConfig.graphQlClient();

    orderCreatedStream = graphQlClient.subscribe(
      SubscriptionOptions(document: orderCreatedGql),
    );
    orderUpdatedStream = graphQlClient.subscribe(
      SubscriptionOptions(document: orderUpdatedGql),
    );

    mergedStream = MergeStream([orderCreatedStream, orderUpdatedStream]);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        StreamBuilder(
          stream: mergedStream,
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              // print(snapshot);
              print('=======inside stream builder====');
              print(snapshot);
            }
            return Container(
              color: Colors.green,
            );
          },
        ),
        Align(
          alignment: Alignment.bottomRight,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: FloatingActionButton.extended(
              onPressed: createDummyOrder,
              label: const Text('Add Order'),
              icon: const Icon(Icons.add),
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomLeft,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: FloatingActionButton.extended(
              onPressed: () async {
                final orderIDToUpdate =
                    orderIds[Random().nextInt(orderIds.length)];

                await updateDummyOrder(orderIDToUpdate);
              },
              label: const Text('Update some Order'),
              icon: const Icon(Icons.add),
            ),
          ),
        )
      ],
    );
  }
}
