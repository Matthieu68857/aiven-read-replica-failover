# Aiven Read-replica failover using Terraform

This is a quick example on how to setup a multi-region infrastructure on Aiven, and how to trigger a failover using Terraform.

# Setup 

The code is pretty simple, it deploys two Aiven Postgres services and configure one of the service as a read-replica using an `aiven_service_integration` resource.

```
resource "aiven_service_integration" "pg-readreplica" {
  project                  = var.project_name
  integration_type         = "read_replica"
  source_service_name      = aiven_pg.demo-master.service_name
  destination_service_name = aiven_pg.demo-read-replica.service_name
}
```

The other important part is in the read-replica configuration where you have to indicate a few parameters:

```
  pg_user_config {
    service_to_fork_from = aiven_pg.demo-master.service_name
    
    pglookout {
      max_failover_replication_time_lag = 60
    }

    dynamic ip_filter_object {      
      for_each = var.ips
      content {
        network = ip_filter_object.value["network"]
        description =ip_filter_object.value["description"]
      }
    }
  }

  service_integrations {
    integration_type    = "read_replica"
    source_service_name = aiven_pg.demo-master.service_name
  }
```

# Failover

Now that your infrastructure is ready, we would like to trigger the failover.
Nothing simpler, you only have to remove the part we just mentioned about the read-replica integration and you're good.
Your terraform will look like this:

```
resource "aiven_pg" "demo-master" {
  project                 = var.project_name
  cloud_name              = var.service_cloud
  plan                    = var.service_plan_pg
  service_name            = "${var.service_name_prefix}-master"

  pg_user_config {
    pg_version            = "15"

    dynamic ip_filter_object {      
      for_each = var.ips
      content {
        network = ip_filter_object.value["network"]
        description =ip_filter_object.value["description"]
      }
    }
  }
}

resource "aiven_pg" "demo-read-replica" {
  project                 = var.project_name
  cloud_name              = var.service_cloud_secondary
  service_name            = "${var.service_name_prefix}-read-replica"
  plan                    = "startup-4"

  pg_user_config {
    pg_version            = "15"

    dynamic ip_filter_object {      
      for_each = var.ips
      content {
        network = ip_filter_object.value["network"]
        description =ip_filter_object.value["description"]
      }
    }
  }

}
```

And voilà !

```
terraform apply 

aiven_service_integration.pg-readreplica: Refreshing state... [id=mcornillon-demo/349bdd61-f12a-4981-a1da-105635744170]
aiven_pg.demo-read-replica: Refreshing state... [id=mcornillon-demo/decathlon-read-replica]
aiven_pg.demo-master: Refreshing state... [id=mcornillon-demo/decathlon-master]

Terraform used the selected providers to generate the following execution plan. Resource actions are indicated with the following symbols:
  ~ update in-place
  - destroy

Terraform will perform the following actions:

  # aiven_pg.demo-read-replica will be updated in-place
  ~ resource "aiven_pg" "demo-read-replica" {
        id                      = "mcornillon-demo/decathlon-read-replica"
        # (20 unchanged attributes hidden)

      - service_integrations {
          - integration_type    = "read_replica" -> null
          - source_service_name = "decathlon-master" -> null
        }

        # (2 unchanged blocks hidden)
    }

  # aiven_service_integration.pg-readreplica will be destroyed
  # (because aiven_service_integration.pg-readreplica is not in configuration)
  - resource "aiven_service_integration" "pg-readreplica" {
      - destination_service_name = "decathlon-read-replica" -> null
      - id                       = "mcornillon-demo/349bdd61-f12a-4981-a1da-105635744170" -> null
      - integration_id           = "349bdd61-f12a-4981-a1da-105635744170" -> null
      - integration_type         = "read_replica" -> null
      - project                  = "mcornillon-demo" -> null
      - source_service_name      = "decathlon-master" -> null
    }

Plan: 0 to add, 1 to change, 1 to destroy.

Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value: yes

aiven_service_integration.pg-readreplica: Destroying... [id=mcornillon-demo/349bdd61-f12a-4981-a1da-105635744170]
aiven_service_integration.pg-readreplica: Destruction complete after 0s
aiven_pg.demo-read-replica: Modifying... [id=mcornillon-demo/decathlon-read-replica]
aiven_pg.demo-read-replica: Still modifying... [id=mcornillon-demo/decathlon-read-replica, 10s elapsed]
aiven_pg.demo-read-replica: Still modifying... [id=mcornillon-demo/decathlon-read-replica, 20s elapsed]
aiven_pg.demo-read-replica: Still modifying... [id=mcornillon-demo/decathlon-read-replica, 30s elapsed]
aiven_pg.demo-read-replica: Still modifying... [id=mcornillon-demo/decathlon-read-replica, 40s elapsed]
aiven_pg.demo-read-replica: Still modifying... [id=mcornillon-demo/decathlon-read-replica, 50s elapsed]
aiven_pg.demo-read-replica: Modifications complete after 58s [id=mcornillon-demo/decathlon-read-replica]

Apply complete! Resources: 0 added, 1 changed, 1 destroyed.
```