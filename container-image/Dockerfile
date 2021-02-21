FROM  registry.redhat.io/openshift4/ose-cli
RUN wget -q https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64
RUN cp jq-linux64 /usr/bin/jq
RUN chmod +x /usr/bin/jq
ADD ./50-machine-entitlements.yaml.template 50-machine-entitlements.yaml.template
ADD ./refresh-entitlement.sh refresh-entitlement.sh 
ENTRYPOINT ["./refresh-entitlement.sh"]
USER 1000
