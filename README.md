# KASU
KASU: (K)ubeadm (A)uto (S)etup on (U)buntu

I want to make a bunch of kubernetes machines but I don't want to create an ISO with everything loaded on it.
So I'll make a script which can be run on a fresh install of JJ Ubuntu, to give me:
1. containerd
2. kubeadm
3. cilium

so that I can either make a control plane or join into one. 👍

Command:
```bash
wget -O kasu.sh "https://raw.githubusercontent.com/lu1a/kasu/main/kasu.sh" && chmod +x kasu.sh && ./kasu.sh
```

Suggestions/help/PRs welcome!
