import boto3
import json
import urllib.request

codedeploy = boto3.client('codedeploy', region_name='us-east-1')
ecs = boto3.client('ecs', region_name='us-east-1')

def handler(event, context):
      deployment_id = event['DeploymentId']
      lifecycle_event_hook_execution_id = event['LifecycleEventHookExecutionId']

      try:
          validate(event)
          status = 'Succeeded'
      except Exception as e:
          print(f"Validation failed: {e}")
          status = 'Failed'

      codedeploy.put_lifecycle_event_hook_execution_status(
          deploymentId=deployment_id,
          lifecycleEventHookExecutionId=lifecycle_event_hook_execution_id,
          status=status
      )

def validate(event):
      cluster = 'dev-cluster'
      service = event.get('ServiceName', 'frontend-green')

      # Check ECS tasks are running
      response = ecs.describe_services(cluster=cluster, services=[service])
      svc = response['services'][0]
      running = svc['runningCount']
      desired = svc['desiredCount']

      if running < desired:
          raise Exception(f"Service {service} has {running}/{desired} tasks running")

      print(f"ECS check passed: {running}/{desired} tasks running")

      # Check health endpoint
      tasks = ecs.list_tasks(cluster=cluster, serviceName=service)['taskArns']
      if not tasks:
          raise Exception(f"No tasks found for service {service}")

      task = ecs.describe_tasks(cluster=cluster, tasks=[tasks[0]])['tasks'][0]
      ip = task['attachments'][0]['details']
      ip = next(d['value'] for d in task['attachments'][0]['details'] if d['name'] == 'privateIPv4Address')

      port = 8080 if 'backend' in service else 3000
      health_url = f"http://{ip}:{port}/health"

      req = urllib.request.urlopen(health_url, timeout=5)
      body = json.loads(req.read())

      if body.get('status') != 'ok':
          raise Exception(f"Health check failed: {body}")

      print(f"Health check passed: {health_url}")