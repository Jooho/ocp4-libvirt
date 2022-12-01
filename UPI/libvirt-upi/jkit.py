#!/usr/bin/env python

import click
import os
import sys
import re
from io import StringIO

@click.command()
@click.argument('cmd',
              default='init',
              type=click.Choice(['init', 'prep', 'ocp', 'quay','update', 'clean', 'oneshot' , 'post','dns','auto']))
@click.option('-t','--type',
              default='inventory',
              type=click.Choice(['inventory', 'ocp', 'conf','disconnect']))
@click.option('-op','--operate',
              default='apply',
              type=click.Choice(['apply', 'dtr']))
@click.option('-c','--component',
              default='config',
              type=click.Choice(['ocp', 'prep', 'matchbox', 'quay','download','config','auto','all']))
@click.help_option('--help', '-h')
@click.option('-v', '--verbose', count=True)
def launch(cmd=None,
           operate=None,
           status=None,
           type=None,
           component=None,
           clusterName=None,
           verbose=0):

    disconnected =""
    cleanAll=""
    pat = re.compile("cluster_name")
    with open ('config', 'rt') as configfile:  
       for line in configfile:      
           if(pat.search(line) != None):
               clusterName=str(line.split("=")[1]).replace("\"", "").replace("\n","")
           

    if verbose > 0:
        verbosity = '-' + 'v' * verbose
    else:
        verbosity = ''

    if type == 'disconnect':
       disconnected="-e disconnected=true"
    
    clean_component="-e clean_component={}".format(component)   
# Construct ansible command
    if cmd == 'init':
       status = os.system(
         'ansible-playbook %s  -i config prep/ansible/tasks/setting_init_env.yml --flush-cache; \
         ansible-playbook %s  -i config prep/ansible/tasks/generate_config_files.yml %s --flush-cache; \
         cd prep;  \
         ansible-playbook %s  -i ansible/inventory ansible/tasks/cloud_init.yml  --flush-cache' \

                % (verbosity, verbosity, disconnected, verbosity )
       )

    if cmd == 'prep':
       if operate == 'apply':
          status = os.system(
           'cd prep;  \
            ansible-playbook %s  -i ansible/inventory ansible/playbooks/prep.yml  -e @ansible/defaults/main.yml %s --flush-cache; \
            terraform init ; \
            terraform get ; \
            terraform apply -auto-approve' 

                % (verbosity, disconnected)
          )
       if operate == 'dtr':
          status = os.system(
           'cd prep;  \
            terraform destroy -auto-approve' 
          )

    if cmd == 'auto':
         status = os.system(
         'prep/upi/custom-update.sh &'
         )
         
    if cmd == 'ocp':
       if operate == 'apply':
          status = os.system(
           'cd ocp4;  \
            terraform init ; \
            terraform get ; \
            terraform apply -auto-approve ;\
            cd ../prep; sudo ./ansible/bin/openshift-install --dir %s wait-for bootstrap-complete; cd ../'
             
                % (clusterName)
          )
       if operate == 'dtr':
          status = os.system(
           'cd ocp4;  \
            terraform destroy -auto-approve' 
          )



    if cmd == 'oneshot':
       status = os.system(
        'ansible-playbook %s  %s -i config prep/ansible/tasks/setting_init_env.yml  --flush-cache; \
         ansible-playbook %s %s -i config prep/ansible/tasks/generate_config_files.yml --flush-cache; \
         cd prep;  \
         ansible-playbook %s -i ansible/inventory ansible/tasks/cloud_init.yml  --flush-cache; \
         ansible-playbook %s  -i ansible/inventory ansible/playbooks/prep.yml  -e @ansible/defaults/main.yml %s --flush-cache; \
         terraform init ; terraform get ; terraform apply -auto-approve; \
         cd ../ocp4;  terraform init ; terraform get ; terraform apply -auto-approve; \
         cd ../prep; sudo ./ansible/bin/openshift-install --dir %s wait-for bootstrap-complete; \
         echo "Waiting 20 secs"; sleep 20; \
         ansible-playbook %s -i ansible/inventory ansible/tasks/lb_rm_bootstrap.yml ; \
         sudo ./ansible/bin/openshift-install --dir %s/ wait-for install-complete'
         

                % (verbosity, disconnected, verbosity, disconnected, verbosity, verbosity, disconnected, clusterName, verbosity, clusterName)
       )

    if cmd == 'post':
        status = os.system(
        'cd ./prep; \
         ansible-playbook %s -i ansible/inventory ansible/tasks/lb_rm_bootstrap.yml ; \
         sudo ./ansible/bin/openshift-install --dir %s wait-for install-complete'

                % (verbosity, clusterName)
       )


    if cmd == 'update':
       if type == 'inventory':
          status = os.system(
           'ansible-playbook %s -i config prep/ansible/tasks/generate_config_files.yml --flush-cache'
   
                   % (verbosity )
           )
       if type == 'ocp':
          status = os.system(
           'ansible-playbook %s  -i config prep/ansible/tasks/generate_config_files.yml --flush-cache; \
            cd prep;  \
            ansible-playbook -i ansible/inventory ansible/tasks/ocp_vm_config.yml  %s -e @ansible/defaults/main.yml %s'
                   % (verbosity, verbosity, disconnected )

           )
       if type == 'ocp_module':
          status = os.system(
           'cd prep;  \
            ansible-playbook -i ansible/inventory ansible/tasks/ocp_module.yml  %s -e @ansible/defaults/main.yml'
                   % (verbosity, verbosity )
           )

    if cmd == 'quay':
       if operate == 'apply':
         status = os.system(
         'cd prep; \
         ansible-playbook %s -i ../config ansible/tasks/quay.yml --flush-cache'
                  % (verbosity)
         )


    if cmd == 'clean':
       if component in ['ocp','all']:
          status = os.system(
            'cd ocp4 ; terraform destroy -auto-approve'
          )
       
       if component in ['prep','all']:
          status = os.system(
            'cd prep ; terraform destroy -auto-approve'
          )
        
       if component in ['auto','all']:
          status = os.system(
            "hacks/clean_auto.sh"
          )     
          
       if component not in ['ocp','prep']:
         status = os.system(
         'cd prep;ansible-playbook %s -i ../config ansible/tasks/clean.yml  %s --flush-cache'
               % (verbosity, clean_component)
      )
      
      
      
      
    if cmd == 'dns':
       if operate == 'apply':
         status = os.system(
         'cd prep; \
         ansible-playbook %s -i ansible/inventory ansible/tasks/dns_config.yml --flush-cache'
                  % (verbosity)
         )
       if operate == 'dtr':
          status = os.system(
         'cd prep; \
         ansible-playbook %s -i ansible/inventory ansible/tasks/dns_config.yml -e op=destory --flush-cache'
                  % (verbosity)
         )



    # Exit appropriately
    if os.WIFEXITED(status) and os.WEXITSTATUS(status) != 0:
        sys.exit(os.WEXITSTATUS(status))


if __name__ == '__main__':
    launch(auto_envvar_prefix='OCP4_UPI_KVM')

