# Jira Evaluation

This template starts a VM, creates a mysql database and sets up jira up to the point where you have to configure it.
It is still necessary to go to the web interface and put the following information in:

- What kind of DB: mysql
dbname, username and passwort is stored in the file "dbcredentials" on the 
created VM.

## Set it up:

``` openstack stack create -t jira-trial.yaml -e jira-trial_env.yaml -e jira-trial_env_secrets.yaml <stackName> --wait ``` 

wait for the stack to be created, then login to the server:

``` openstack server ssh -l syseleven jira-trialserver ```

``` cat dbcredenitals ```

--> Head over to your browser and fill in the server ip. The rest is done using the web formular.





