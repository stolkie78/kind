 #!/bin/bash
 
 kubectl port-forward svc/argocd-server -n argocd 8080:443 &
 kubectl port-forward -n kubernetes-dashboard service/kubernetes-dashboard 8443:443 &

 wait