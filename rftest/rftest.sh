#!/bin/bash

################################################################################
#                                                                              #
#                      Console de Gerenciamento das VMs                        #
#                                                                              #
################################################################################

# Instalacao de pacotes
apt-get install -y dialog lxc qemu kvm libvirt-bin libvirt-dev libvirt0 virt-manager 

# Inicio da configuração das VMs
dialog --title 'rftest2' --msgbox '\nA partir de agora será necessário configurar as 4 VMs de acordo com o Hypervisor desejado.' 9 40

Existente(){
    # Seleciona XML Existente
    XMLSOURCE=`dialog --stdout --title 'Selecione o XML' --fselect XML/ 0 0`
    
    if [ -f ${XMLSOURCE} ]
    then
        # Realiza tratamento sobre o XML para obter o hypervisor definido no XML
        XMLCONTENT=`cat "$XMLSOURCE"`
        HYPERVISOR=`echo $XMLCONTENT | cut -c15`
    else
        dialog --title 'Alerta!' --msgbox '\nVocê deve selecionar um arquivo XML!' 6 40
        Existente
    fi
}

Novo(){
    # Invoca script da Wizard geradora de XML de configuração
    sh libvirt.sh
    
    # Realiza tratamento sobre o XML para obter o hypervisor selecionado na Wizard
    XMLSOURCE=`cat ~temp`
    rm ~temp
    XMLCONTENT=`cat $XMLSOURCE`
    HYPERVISOR=`echo $XMLCONTENT | cut -c15`
}

QEMU(){
    #INSERIR CÓDIGO LIBVIRT PARA STARTAR VM COM QEMU
    (
        echo 0
        sleep 1
        virsh -c qemu:///system destroy $XMLNAME    
        echo 25
        sleep 1
        virsh -c qemu:///system undefine $XMLNAME
        echo 50
        sleep 1
        virsh -c qemu:///system define $XMLSOURCE
        echo 75
		sleep 1
        virsh -c qemu:///system start $XMLNAME
        echo 100
    ) | dialog --title "$rfvmX" --gauge "\nIniciando $rfvmX com qemu..." 8 40 0
}

LXC(){
    #INSERIR CÓDIGO LIBVIRT PARA STARTAR VM COM LXC
    (
        echo 0
        sleep 1
        virsh -c lxc:/// destroy $XMLNAME    
        echo 25
        sleep 1
        virsh -c lxc:/// undefine $XMLNAME
        echo 50
        sleep 1
        virsh -c lxc:/// define $XMLSOURCE
        echo 75
        sleep 1
        virsh -c lxc:/// start $XMLNAME
        echo 100
    ) | dialog --title "$rfvmX" --gauge "\nIniciando $rfvmX com lxc..." 8 40 0
}

KVM(){
    #INSERIR CÓDIGO LIBVIRT PARA STARTAR VM COM KVM
    (
        echo 0
        sleep 1
        virsh -c kvm:/// destroy $XMLNAME    
        echo 25
        sleep 1
        virsh -c kvm:/// undefine $XMLNAME
        echo 50
        sleep 1
        virsh -c kvm:/// define $XMLSOURCE
        echo 75
        sleep 1
        virsh -c kvm:/// start $XMLNAME
        echo 100
    ) | dialog --title "$rfvmX" --gauge "\nIniciando $rfvmX com kvm..." 8 40 0
}

DEFINEIMAGETOXML(){
    case "$rfvmX" in
	"rfvmA")
	    STR="h1"
	    ;;
	"rfvmB")
	    STR="h2"
	    ;;
	"rfvmC")
	    STR="h3"
	    ;;
	"rfvmD")
	    STR="h4"
	    ;;
    esac
    sed -i "s/hXX/$STR/g" $XMLSOURCE
    sed -i "s/h1/$STR/g" $XMLSOURCE
    sed -i "s/h2/$STR/g" $XMLSOURCE
    sed -i "s/h3/$STR/g" $XMLSOURCE
    sed -i "s/h4/$STR/g" $XMLSOURCE
}

CONFIGVM(){
    # Selecionar XML Existente ou Criar Novo XML
    opmenu=$(dialog --stdout --title "$rfvmX" --menu 'Você deseja utilizar um XML existente ou deseja criar um novo XML?' 0 0 0 Novo 'Configurar nova VM' Existente 'Selecionar XML existente')

    if [ $opmenu = "Novo" ]
    then
        Novo
    else
        Existente
    fi

    DEFINEIMAGETOXML

    XMLNAME=`basename "$XMLSOURCE" .xml`

    # Verifica qual hypervisor para executar sequencia de comandos do libvirt para startar as VMs
    case $HYPERVISOR in
        "q")
            QEMU
            ;;
        "l")
            LXC
            ;;
        "k")
            KVM
            ;;
    esac
}

# Configuração das 4 VMs: rfvmA, rfvmB, rfvmC e rfvmD
rfvmX="rfvmA"
CONFIGVM
rfvmX="rfvmB"
CONFIGVM
rfvmX="rfvmC"
CONFIGVM
rfvmX="rfvmD"
CONFIGVM
