O principal objetivo do projeto é criar testes para o ERC 4337 usando tanto técnicas de caixa preta quanto de caixa branca. Nossos testes usaram a estrutura do foundry para execução. Além disso, fizemos a execução dos testes usando tanto o halmos quanto o hevm para testes simbólicos. A seguir detalharemos mais sobre nossa experiência e aprendizados.

Nosso foco era testar as funções que executam alguma ação, principalmente as que fazem alguma transação, uma vez que são essas funções que fazem tudo funcionar. Dessa forma, considerando esse cenário, criamos testes para as seguintes funções:

## black-box testing
Até a presente data, não focamos muito nesse tipo de teste, na verdade, fizemos poucos tipos de testes (de funções específicas e que serão citadas posteriormente neste documento). Nesse cenário, fizemos testes para as seguintes funções: depositTo, e withdrawTo pois são funções simples. 

## White-box testing
Quanto aos testes de caixa-branca, novamente analisamos função a função e, nesse caso, quaisquer outras função (internas ou externas) chamadas dentro da implementação de cada uma. Nesse cenário, analisamos a implementação de **eth-infinitism**. Descreveremos a seguir o que fizemos e nossos resultados. 

Se olharmos atentamente a implementação do método para depósito, não há muita complexidade, não há fluxo de decisão, nada. Por esta razão, não houve muito o que fazer no sentido de novos testes, i.e, o importante é analisar se após a chamada e execução do método a conta passada por parâmetro possui o valor maior que inicial. 

O mesmo vale para a função de saque (withdrawTo), por esta e por outras razões, optamos por testar a principal função do EntryPoint (handleOps). A função (handleOps) chama várias outras funções durante sua execuçaõ, seja direta ou indiretamente. A medida que fomos evoluindo nos testes, adicionaremos explicações do que foi feito: 

- Ao iniciar a execução da _handleOps_ a primeira função que gera algum tipo de alteração ou controle de fluxo é a **_validatePrepayment** que pode gerar alguns _reverts_, sendo eles:

1. AA94 gas values overflow: _Reverte se a soma dos atributos do **PackedUserOperation** sejam maiores que um valor máximo._
2. AA25 invalid account nonce: _Reverte caso o contador (_nonce_) não for válido
3. AA26 over verificationGasLimit: _Reverte no caso do gás usado na transação seja maior que o limite setado no atributo **verificationGasLimit**_

- Dessa maneira, esses foram os primeiros testes criados, testes que buscassem "alcançar" esses cenários.

# Execução Simbólica (Hevm e Halmos)

Um dos nossos objetivo com esse projeto é também executar os testes com hevm e halmos, ambas ferramentas para execução de testes simbólicos, apesar das abordagens diferentes. Até agora, conseguimos fazer a executação apenas com o (halmos), mas em breve faremos testes com o (hevm) também. 

Nesse sentido, foi possível ver que os testes que escrevemos estão focados totalmente na execução "concreta" dos métodos, isto é, 

Ao pesquisar um pouco, foi possível descobrir coisas interessantes sobre a diferença de execução com testes simbólicos e concretos, por exemplo, ao executar nossos testes com o (halmos) lidamos principalmente com 2 problemas:

1. O halmos não suporta testes com "expectRevert", considerando que é "cheat code", no entanto, a maioria dos nossos testes esperavam isso devido a maneira que idealizamos ou talvez começamos o desenvolvimento desse projeto, sendo algo que é possível ser revisto depois. 

2. Estados iniciais restritivos demais. Nesse caso, limitados demais o que pode ser feito, faz sentido. Em algumas situações, para que algumas funções fossem testadas propositalmente limitados o que poderia ser feito, por exemplo, setando limites de gás insuficientes forçando com que algum "require" falhasse. 

Dessa maneira, é interessante mudarmos nossa maneira de fazer os testes, pensando de maneira mais abrangente, que seja possível tanto executar os testes de maneira concreta quanto simbólica. 

Para que seja guardado para futuras evoluções, na primeira execução do halmos, a única função que passou foi **check_testDepositZeroEther_ShouldNotChangeBalance**