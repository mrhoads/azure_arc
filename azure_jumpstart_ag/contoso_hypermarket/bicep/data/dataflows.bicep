@description('The name of the IoT Operations instance')
param aioInstanceName string

@description('The name of the custom location')
param customLocationName string

@description('The name of the Event Hub namespace')
param evenHubNamespaceHost string

@description('The name of the Event Hub')
param eventHubName string

@description('The name of the IoT data flow')
param iotDataFlowName string = 'iot-mqtt-to-eventhub'

@description('The name of the commercial data flow')
param commercialDataFlowName string = 'commercial-mqtt-to-eventhub'
param defaultDataflowEndpointName string = 'default'
param eventHubDataflowEndpointName string = 'eventhub-endpoint'

resource aioInstance 'Microsoft.IoTOperations/instances@2024-08-15-preview' existing = {
  name: aioInstanceName
}

resource customLocation 'Microsoft.ExtendedLocation/customLocations@2021-08-31-preview' existing = {
  name: customLocationName
}

resource eventhubEndpoint 'Microsoft.IoTOperations/instances/dataflowEndpoints@2024-08-15-preview' = {
  parent: aioInstance
  name: eventHubDataflowEndpointName
  extendedLocation: {
    name: customLocation.id
    type: 'CustomLocation'
  }
  dependsOn: [
    customLocation
  ]
  properties: {
    endpointType: 'Kafka'
    kafkaSettings: {
      host: evenHubNamespaceHost
      authentication: {
        method: 'SystemAssignedManagedIdentity'
        systemAssignedManagedIdentitySettings: {}
      }
      tls: {
        mode: 'Enabled'
      }
      batching: {
        latencyMs: 1000
        maxMessages: 100
        maxBytes: 1024
      }
      kafkaAcks: 'All'
      copyMqttProperties: 'Enabled'
      consumerGroupId: 'mqConnector'
    }
  }
}

// Pointer to the default dataflow profile
resource defaultDataflowProfile 'Microsoft.IoTOperations/instances/dataflowProfiles@2024-08-15-preview' existing = {
  parent: aioInstance
  name: 'default'
}

resource iotDataFlow 'Microsoft.IoTOperations/instances/dataflowProfiles/dataflows@2024-08-15-preview' = {
  // Reference to the parent dataflow profile, the default profile in this case
  // Same usage as profileRef in Kubernetes YAML
  parent: defaultDataflowProfile
  name: iotDataFlowName
  extendedLocation: {
    name: customLocation.id
    type: 'CustomLocation'
  }
  properties: {
    mode: 'Enabled'
    operations: [
      {
        operationType: 'Source'
        sourceSettings: {
          endpointRef: defaultDataflowEndpointName
          dataSources: [
            'iot/devices/#'
          ]
        }
      }
      {
        operationType: 'BuiltInTransformation'
        builtInTransformationSettings: {
          // See transformation configuration section
        }
      }
      {
        operationType: 'Destination'
        destinationSettings: {
          endpointRef: eventHubDataflowEndpointName
          dataDestination: eventHubName // See section on configuring data destination
        }
      }
    ]
  }
}

resource commercialDataFlow 'Microsoft.IoTOperations/instances/dataflowProfiles/dataflows@2024-08-15-preview' = {
  // Reference to the parent dataflow profile, the default profile in this case
  // Same usage as profileRef in Kubernetes YAML
  parent: defaultDataflowProfile
  name: commercialDataFlowName
  extendedLocation: {
    name: customLocation.id
    type: 'CustomLocation'
  }
  properties: {
    mode: 'Enabled'
    operations: [
      {
        operationType: 'Source'
        sourceSettings: {
          endpointRef: defaultDataflowEndpointName
          dataSources: [
            'topic/commercial'
          ]
        }
      }
      {
        operationType: 'BuiltInTransformation'
        builtInTransformationSettings: {
          // See transformation configuration section
        }
      }
      {
        operationType: 'Destination'
        destinationSettings: {
          endpointRef: eventHubDataflowEndpointName
          dataDestination: eventHubName
        }
      }
    ]
  }
}