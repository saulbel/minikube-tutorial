# Minikube Tutorial

## Prerequisites
Things you need before starting:
* `Docker`
* `Minikube`
* `Kubectl`
* `Skaffold`

## Project structure
```
minikube-tutorial
|── Dockerfile
|── app.py
|── deployment.yaml
|── service.yaml
|── skaffold.yaml
|── README.md
|── scripts
|    └── setup.sh
|    └── tools.sh
└── .github/workflows/
     └── docker-publish.yml
```
## Tasks to accomplish
- Dockerize the microservice (`app.py`).
- Deploy the microservice to `minikube`.
- Use `skaffold` to build docker images and deploy to minikube.

## How to install the tools
I have included a custom script `setup.sh` that allows you to install `docker`, `minikube`, `kubectl` and `skaffold` on `Debian`.
I recommend to download it and change it with your `username` because I have decided to add my `user` to `docker group`. It is a good practice to run docker with a user instead of as `root`.

## How to setup this project locally
- First we should download it with either `git clone` or as `.zip`.
- Then we will modify `/scripts/setup.sh` with our `username` and we will execute it.
- Finally we just jump into the first task.

## First task: dockerize the microservice
- In order to do this we are gonna use both `Dockerfile` and `requirements.txt`. We are gonna create a custom docker image that includes our `app.py` and the dependencies required to run. So in order to build this image we are gonna use `docker build -t saul/geoblink .` and then we will check out our custom image using `docker images`:
````
$ docker images
REPOSITORY                        TAG                    IMAGE ID       CREATED        SIZE
saul/geoblink                     latest                 f0ce85ec3bc7   19 hours ago   80.9MB
````
- Finally we will run our image with `docker run`:
````
$ docker run -d -p80:8000 saul/geoblink
adcbd64663450a8d2751b4fe21f84203cc813a3b43af7bc2432976ce7f0d89bd
$ docker ps
CONTAINER ID   IMAGE                                 COMMAND                  CREATED         STATUS          PORTS                             NAMES
adcbd6466345   saul/geoblink                         "python app.py"          3 seconds ago   Up 2 seconds    0.0.0.0:80->8000/tcp, :::80->8000/tcp                                                                                                  affectionate_colden
````
- Now we just have to test it with `curl`.
````
$ curl localhost:80     --> host          --> working
$ curl localhost:8000   --> container     --> working
````

## Second task: deploy the microservice to minikube
- First of all we are gonna start `minikube` with `minikube start`
- Now if we check out our containers running with `docker ps` we can see a docker daemon from `minikube`:
````
CONTAINER ID   IMAGE                                 COMMAND                  CREATED          STATUS          PORTS                                                                                                                                  NAMES
a34aadbbd833   gcr.io/k8s-minikube/kicbase:v0.0.30   "/usr/local/bin/entr…"   17 hours ago     Up 31 minutes   127.0.0.1:49157->22/tcp, 127.0.0.1:49156->2376/tcp, 127.0.0.1:49155->5000/tcp, 127.0.0.1:49154->8443/tcp, 127.0.0.1:49153->32443/tcp   minikube
````
- So what's the plan? The idea is to reuse the docker daemon with `eval $(minikube docker-env)` so we build the image inside it. We could also access into minikube's node like this `minikube ssh`. Now we are gonna create the image like we did in the first step `docker build -t saul/geoblink .`
- Now to run it we just:
````
$ kubectl run geoblink-app --image=saul/geoblink --image-pull-policy=Never
pod/geoblink-app created
$ kubect get pods
NAME           READY   STATUS    RESTARTS   AGE
geoblink-app   1/1     Running   0          1s
````
- So that's it right? Let's test it again with `curl`. As you already can imagine, it is working inside the container but not from outside. Why? Because our pod is not exposed so It can not be reached from outside the cluster.
````
$ curl localhost:80     --> host            --> not working
$ curl localhost:8000   --> pod's container --> working
````
- In order to do this, first we are create what `kubernetes` call `manifests`. One for deploying our application `deployment.yaml` and another for exposing our application `service.yaml`. We are gonna apply these manifests:
````
$ kubectl apply -f deployment.yaml
deployment.apps/geoblink-app created
$ kubectl get pods
NAME                            READY   STATUS    RESTARTS   AGE
geoblink-app-57cc9768f7-cnj5j   1/1     Running   0          18m
geoblink-app-57cc9768f7-kv4wn   1/1     Running   0          18m
geoblink-app-57cc9768f7-pj64c   1/1     Running   0          18m
$ kubectl apply -f service.yaml
service/geoblink-app-service configured
$ kubectl get svc
NAME                   TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
geoblink-app-service   NodePort    10.99.168.218   <none>        80:32635/TCP   18m
kubernetes             ClusterIP   10.96.0.1       <none>        443/TCP        18h
````
- Let's talk about services, what we did before with `kubectl run` exposed our application with a `ServiceType` called `ClusterIP`, making our application reachable from within the cluster. That is why we could not access our app from outside the cluster, it is also the default `Servicetype`. In order to make our application be reachable from outside the cluster we are gonna use another service type called `NodePort`. So we need both `NodeIp` and `NodePort`:
````
$ minikube ip
192.168.49.2
$ kubectl get svc
NAME                   TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
geoblink-app-service   NodePort    10.99.168.218   <none>        80:32635/TCP   13m
````
- Now we can `curl` from both `inside` and `outside` the cluster:
````
$ curl http://192.168.49.2:32635 --> outside the cluster
$ curl localhost:8000            --> inside pod's container
````
- Before going into the final task, let's talk about a little bit more about networking. Basically with this setup we have 3 ways of accesing our application.
````
# <node-ip>:<node-port>
$ curl http://192.168.49.2:32635 
# <service-ip>:<service-port>
$ curl http://10.99.168.218:80
# <pod-ip>:<target-port>
$ curl http://172.17.0.4:8000
````
- We also have 3 different situations: `inside a pod` (node-ip, service-ip and pod-ip will work), `on a node` (node-ip, service-ip and pod-ip will work) and `outside the node` (only node-ip will work)

## Third task: use skaffold to build docker images and deploy to minikube
What if we want to automate the whole process, I mean, build the custom `docker` image, push it into `minikube` and deploy it using both `deployment.yaml` and `service.yaml` files. We are gonna use `skaffold` for that.
- First we are gonna create our project configuration `skaffold.yaml`:
````
$ skaffold init
apiVersion: skaffold/v2beta28
kind: Config
metadata:
  name: minikube-tutorial
build:
  artifacts:
  - image: saul/geoblink
    docker:
      dockerfile: Dockerfile
deploy:
  kubectl:
    manifests:
    - deployment.yaml
    - service.yaml
````

- As we can see, if we execute the command `skaffold init` in our project folder `/minikube/.` it will automatically generate the `skaffold.yaml`. Now we will just have to run it and it will do the whole process by itself. In just 6 seconds we have our application deployed on `minikube`. Awesome right? :)
````
$ skaffold run
Generating tags...
 - saul/geoblink -> saul/geoblink:a5edb49-dirty
Checking cache...
 - saul/geoblink: Not found. Building
Starting build...
Found [minikube] context, using local docker daemon.
Building [saul/geoblink]...
Build [saul/geoblink] succeeded
Starting test...
Tags used in deployment:
 - saul/geoblink -> saul/geoblink:ae1061b2f89c1301b30582549903be77e23fccded231b5a343705bd6fed197d6
Starting deploy...
 - deployment.apps/geoblink-app configured
 - service/geoblink-app-service configured
Waiting for deployments to stabilize...
 - deployment/geoblink-app: creating container geoblink-app
    - pod/geoblink-app-5c4947966c-glzx5: creating container geoblink-app
 - deployment/geoblink-app is ready.
Deployments stabilized in 6.07 seconds
````
## GitHub Actions
I have built a CI pipeline that builds a custom docker image with `Dockerfile` and pushes it into GitHub container registry  `ghcr.io`. If I want to pull latest `docker image` I will just have to:
````
$ docker pull ghcr.io/saulbel/minikube-tutorial:main
$ docker images
REPOSITORY                                TAG                                                                IMAGE ID       CREATED             SIZE
ghcr.io/saulbel/minikube-tutorial         main                                                               7e6a7183e793   5 minutes ago       90.3MB
````
