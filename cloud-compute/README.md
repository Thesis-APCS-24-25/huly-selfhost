To create a new instance, use the following command, should be executed in `huly-selfhost/google-cloud`
where `startup.sh` script is present.
```bash
gcloud compute instances create "<INSTANCE_NAME>" \
    --project=thesis2425-468203 \
    --zone=asia-southeast1-a \
    --machine-type=e2-medium \
    --network-interface=address=34.124.230.56,network-tier=PREMIUM,stack-type=IPV4_ONLY,subnet=default \
    --metadata=enable-osconfig=TRUE \
    --metadata-from-file=startup-script=startup.sh \
    --maintenance-policy=MIGRATE \
    --provisioning-model=STANDARD \
    --service-account=platform-service-account@thesis2425-468203.iam.gserviceaccount.com \
    --scopes=https://www.googleapis.com/auth/cloud-platform \
    --tags=http-server,https-server \
    --create-disk=auto-delete=yes,boot=yes,device-name=test-2,image=projects/debian-cloud/global/images/debian-12-bookworm-v20250513,mode=rw,size=10,type=pd-balanced \
    --no-shielded-secure-boot \
    --shielded-vtpm \
    --shielded-integrity-monitoring \
    --labels=goog-ops-agent-policy=v2-x86-template-1-4-0,goog-ec-src=vm_add-gcloud \
    --reservation-affinity=any \
```
