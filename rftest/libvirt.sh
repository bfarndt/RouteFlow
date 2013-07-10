#!/bin/bash

################################################################################
#                                                                              #
#                      Wizard LibVirt with Dialog                              #
#                                                                              #
################################################################################

Main(){
# Instalação de pacotes (LibVirt + Dialog)
sudo apt-get install -y dialog libvirt-bin libvirt-dev libvirt0 virt-manager

# Cria diretório XML onde serão salvos os XMLs gerados
mkdir -p XML

Domain

touch ~temp
echo "$FILE" > ~temp
}

Domain(){
    # Escolha do Hypervisor
    tempfile=`tempfile 2>/dev/null` || tempfile=/tmp/test$$
    trap "rm -f $tempfile" 0 1 2 5 15
    dialog --backtitle "Wizard LibVirt v1.0" --radiolist "Escolha o Hypervisor:" 11 40 5 "kvm" "" off "qemu" "" off "lxc" "" on 2> $tempfile
    HYPERVISOR=`cat $tempfile`

    # Leitura do ID da VM
    dialog --cr-wrap --clear --inputbox "ID da VM (O ID deve ser único para cada VM): " 0 0 2> $tempfile
    ID=`cat $tempfile`

    # Leitura do Nome da VM
    dialog --cr-wrap --clear --inputbox "Nome da VM: " 0 0 2> $tempfile
    NAME=`cat $tempfile`

    # Domain XML
    FILE="XML/$NAME.xml"
    echo "<domain type='$HYPERVISOR' id='$ID'>" > $FILE
    echo "\t<name>$NAME</name>" >> $FILE

    OS
    CPU
    MEMORY
    OTHER
    DEVICES

    echo "</domain>" >> $FILE
}

OS(){
    # Escolha do OS
    
    echo "\t<os>" >> $FILE
            
    if [ $HYPERVISOR = "lxc" ]
    then
        echo "\t\t<type>exe</type>" >> $FILE
        echo "\t\t<init>/bin/bash</init>" >> $FILE
    else
        # Arquitetura (i686 ou x86_64)
        dialog --backtitle "Wizard LibVirt v1.0" --radiolist "Escolha a arquitetura do OS:" 11 40 5 "i686" "" on "x86_64" "" off 2> $tempfile
        ARCH=`cat $tempfile`
        
        # Tipo OS: hvm, linux ou exe
        dialog --backtitle "Wizard LibVirt v1.0" --radiolist "Escolha o tipo do OS:" 11 40 5 "hvm" "" on "linux" "" off "exe" "" off 2> $tempfile
        TYPEOS=`cat $tempfile`
        
        echo "\t\t<type arch='$ARCH'>$TYPEOS</type>" >> $FILE
        echo "\t\t<boot dev='hd'/>" >> $FILE        
    fi
    
    echo "\t</os>" >> $FILE
}

CPU(){
    #Quantidade de CPUs
    dialog --cr-wrap --clear --inputbox "Quantidade de CPUs: " 0 0 2> $tempfile
    CORE=`cat $tempfile`

    echo "\t<vcpu>$CORE</vcpu>" >> $FILE
}

MEMORY(){
    # Quantidade de memória
    dialog --cr-wrap --clear --inputbox "Quantidade de memória: " 0 0 2> $tempfile
    MEMORY=`cat $tempfile`
    
    echo "\t<memory unit='MB'>$MEMORY</memory>" >> $FILE
}

OTHER(){
    echo "\t<on_poweroff>destroy</on_poweroff>" >> $FILE
    echo "\t<on_reboot>restart</on_reboot>" >> $FILE
    echo "\t<on_crash>restart</on_crash>" >> $FILE
}

DEVICES(){
    echo "\t<devices>" >> $FILE
    
    DISK
#    INTERFACES
    
    if [ $HYPERVISOR = "lxc" ] 
    then
        echo "\t\t<console type='pty'/>" >> $FILE        
    fi
    
    echo "\t</devices>" >> $FILE
}

DISK(){
    # Define o tipo de disco e o local de sua imagem
    #IMAGE=`dialog --stdout --title "Escolha o caminho da Imagem do SO" --fselect / 14 48`
    
#    if [ -f "${IMAGE}" ]
#    then
        echo "\t\t<disk type='file' device='disk'>" >> $FILE
        echo "\t\t\t<source file='/home/routeflow/RouteFlow/rftest/Images/hXX.img'/>" >> $FILE
        echo "\t\t\t<target dev='hda'/>" >> $FILE
        echo "\t\t</disk>" >> $FILE
#    else
#        dialog --title 'Alerta!' --msgbox "\nErro ao selecionar a Imagem $IMAGE. Verifique se as imagems estao localizadas no diretorio /home/routeflow/Routeflow/rftest/Images/" 10 40
#        exit 0
    #fi
}

#INTERFACES(){
#    # Quantidade de Interfaces
#    dialog --cr-wrap --clear --inputbox "Quantidade de Interfaces: " 0 0 2> $tempfile
#    NUMINTERFACES=`cat $tempfile`
#    
#    for i in `seq 1 $NUMINTERFACES`
#    do
#        INTERFACE
#    done
#}

#INTERFACE(){
#    # Tipo da interface (network ou bridge)
#    dialog --backtitle "Wizard LibVirt v1.0" --radiolist "Escolha o tipo da interface $i:" 11 40 5 "network" "" on "bridge" "" off 2> $tempfile
#    TYPEINTERFACE=`cat $tempfile`
#    
#    # Nome da interface
#    dialog --cr-wrap --clear --inputbox "Qual o nome da interface $i: " 0 0 2> $tempfile
#    NAMEINTERFACE=`cat $tempfile`
#
#    # Nome da interface
#    dialog --cr-wrap --clear --inputbox "Qual o MAC Address da interface $i: " 0 0 2> $tempfile
#    MAC=`cat $tempfile`
#        
#    echo "\t\t<interface type='$TYPEINTERFACE'>" >> $FILE
#    echo "\t\t\t<source $TYPEINTERFACE='$NAMEINTERFACE'/>" >> $FILE
#    echo "\t\t\t<mac address='$MAC'/>" >> $FILE
#    echo "\t\t</interface>" >> $FILE
#}

#case "$1" in
#	"rfvmA")
#		$IMAGE = "/home/routeflow/RouteFlow/rftest/Images/h1.img"
#		;;
#	"rfvmB")
#		$IMAGE = "/home/routeflow/RouteFlow/rftest/Images/h2.img"
#		;;
#	"rfvmC")
#		$IMAGE = "/home/routeflow/RouteFlow/rftest/Images/h3.img"
#		;;
#	"rfvmD")
#		$IMAGE = "/home/routeflow/RouteFlow/rftest/Images/h4.img"
#		;;
#esac

Main
