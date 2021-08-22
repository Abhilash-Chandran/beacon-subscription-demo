import 'dart:async';

import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:nordwind/graphql_config.dart';
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
      home: const Scaffold(body: GraphqlSubscriber()),
    );
  }
}

class GraphqlSubscriber extends StatefulWidget {
  const GraphqlSubscriber({Key? key}) : super(key: key);

  @override
  State<GraphqlSubscriber> createState() => _GraphqlSubscriberState();
}

class Beacon {
  final String beconId;
  final String shortcode;
  final String lattitude;
  final String longitude;

  Beacon({
    required this.beconId,
    required this.shortcode,
    required this.lattitude,
    required this.longitude,
  });
}

class _GraphqlSubscriberState extends State<GraphqlSubscriber> {
  // Initialize a single graphql client instance. Better to register in a service
  // locator or provide through provider or inherited widget.
  final GraphQLClient graphQlClient = GraphQLConfig().graphQlClient();

  // List of stream objects handling beaconLocation and beaconJoined
  // subcriptions as a merged subscription streams.
  final List<StreamSubscription> mergedStreamSubscriptions = [];

  // Gql for beacon location subscription.
  final beaconLocationSubGql = gql(r'''
    subscription StreamBeaconLocation($id: ID!){
      beaconLocation(id: $id){
        lat
        lon
      }
    }
  ''');

  // Gql for oreder updated subscription.
  final beaconJoinedSubGql = gql(r'''
    subscription StreamNewlyJoinedBeacons($id: ID!){
      beaconJoined(id: $id){
        name
        location{
          lat
          lon
        }
      }
    }
  ''');

  // simply in memory array to hold the order id's
  List<Beacon> beacons = [];

  Future<void> createBeacon(BuildContext context) async {
    final createBeaconGql = gql(r'''
        mutation CreateBecon(
            $title: String, 
            $startsAt: Float, 
            $expiressAt: Float!,
            $lat: String!,
            $lon: String!,
          ){
          createBeacon(
            beacon: {
              title: $title
              startsAt: $startsAt
              expiresAt: $expiressAt     
              startLocation: {
                lat: $lat
                lon: $lon
              }
            }
          ){
            _id
            shortcode
            location {
              lat
              lon
            }
          }
        }
      ''');
    MutationOptions mutationOptions = MutationOptions(
      document: createBeaconGql,
      variables: <String, dynamic>{
        'title': mockName(),
        'startsAt': Random().nextDouble(),
        'expiressAt': Random().nextDouble(),
        'lat': Random().nextDouble().toString(),
        'lon': Random().nextDouble().toString(),
      },
    );

    final mutationResutls = await graphQlClient.mutate(mutationOptions);
    // print(mutationResutls);
    final createdBeacon =
        mutationResutls.data?['createBeacon'] as Map<String, dynamic>;
    final newBeacon = Beacon(
      beconId: createdBeacon['_id'],
      shortcode: createdBeacon['shortcode'],
      lattitude: createdBeacon['location']['lat'],
      longitude: createdBeacon['location']['lon'],
    );

    // Note the followin call incldes a setstate to rebuild the ui.
    setupSubscriptionsForNewBeacon(newBeacon, context);
  }

  Future<void> joinBeacon(String shortcode) async {
    final joinBeaconGql = gql(r'''
        mutation JoinBecon($shortcode: String!){
          action: joinBeacon(shortcode: $shortcode){
            shortcode
          }
        }
      ''');
    MutationOptions mutationOptions = MutationOptions(
      document: joinBeaconGql,
      variables: <String, dynamic>{'shortcode': shortcode},
    );

    final mutationResutls = await graphQlClient.mutate(mutationOptions);
    print('Create beacon result is ===> $mutationResutls');
  }

  Future<void> updateLocation(String id) async {
    final updateBeaconLocationGql = gql(r'''
        mutation UpdateBeaconLocation(
            $id: ID!,
            $lat: String!,
            $lon: String!
          ){
          action: updateBeaconLocation(id: $id, location: {
            lat: $lat,
            lon: $lon
          }){
            shortcode
          }
        }
      ''');
    MutationOptions mutationOptions = MutationOptions(
      document: updateBeaconLocationGql,
      variables: <String, dynamic>{
        'id': id,
        'lat': Random().nextDouble().toString(),
        'lon': Random().nextDouble().toString(),
      },
    );

    final mutationResutls = await graphQlClient.mutate(mutationOptions);
    print('Updated beaconlocation result is ===> $mutationResutls');
  }

  void setupSubscriptionsForNewBeacon(Beacon beacon, BuildContext context) {
    final beaconLocationStream = graphQlClient.subscribe(
      SubscriptionOptions(
        document: beaconLocationSubGql,
        variables: <String, dynamic>{
          'id': beacon.beconId,
        },
      ),
    );
    final beaconJoinedStream = graphQlClient.subscribe(
      SubscriptionOptions(
        document: beaconJoinedSubGql,
        variables: <String, dynamic>{
          'id': beacon.beconId,
        },
      ),
    );

    final mergedStream =
        MergeStream([beaconLocationStream, beaconJoinedStream]);
    final mergeStreamSubscription = mergedStream.listen((event) {
      if (event.data != null) {
        if (event.data!.containsKey('beaconJoined')) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('received a beacon joined data ${event.data}')),
          );
        }
        if (event.data!.containsKey('beaconLocation')) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('received a beacon location data ${event.data}')),
          );
        }
      }
    });

    beacons.add(beacon);
    mergedStreamSubscriptions.add(mergeStreamSubscription);
    setState(() {});
  }

  @override
  void dispose() {
    for (var streamSub in mergedStreamSubscriptions) {
      streamSub.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ListView(
          children: [
            ...beacons.map(
              (e) => ExpansionTile(
                backgroundColor: Colors.grey.shade300,
                title: Text('Beacon with short code ${e.shortcode}'),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(18.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        const Spacer(),
                        MaterialButton(
                          color: Colors.green,
                          child: const Text('Join this beacon'),
                          onPressed: () => joinBeacon(e.shortcode),
                        ),
                        const Spacer(),
                        MaterialButton(
                          color: Colors.orangeAccent,
                          child: const Text('Update beacon location'),
                          onPressed: () => updateLocation(e.beconId),
                        ),
                        const Spacer(),
                      ],
                    ),
                  )
                ],
              ),
            )
          ],
        ),
        Align(
          alignment: Alignment.bottomRight,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: FloatingActionButton.extended(
              onPressed: () async => createBeacon(context),
              label: const Text('Create Beacon'),
              icon: const Icon(Icons.add),
            ),
          ),
        ),
      ],
    );
  }
}
