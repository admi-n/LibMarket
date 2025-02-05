pragma circom 2.0.0;

include "merkle.circom";  // 引入 Merkle 树验证组件
// include "../node_modules/circomlib/circuits/mimcsponge.circom";

// // 引入MiMC哈希函数电路库
// include "../node_modules/circomlib/circuits/mimcsponge.circom";


// 定义电路
template BuyerInfoHashCircuit() {
    // 输入交易哈希和买家信息
    signal input tradeHash;          // 交易哈希
    signal input buyerAddressHash;   // 买家收货地址的哈希
    signal input buyerPhoneHash;     // 买家手机号的哈希
    signal input merkleRoot;         // Merkle 树的根哈希
    signal input merklePath[10];     // Merkle 树路径
    signal input merkleIndex;        // Merkle 树路径的索引

    // 定义 Merkle 树验证
    component merkleVerify = Merkle(10);  // 假设树的高度为10
    merkleVerify.root <== merkleRoot;
    merkleVerify.path <== merklePath;
    merkleVerify.index <== merkleIndex;

    // 计算买家信息的综合哈希
    signal buyerInfoHash;
    buyerInfoHash <== sha256(buyerAddressHash, buyerPhoneHash);

    // 组合买家信息的哈希与交易哈希
    signal combinedHash;
    combinedHash <== sha256(tradeHash, buyerInfoHash);

    // 验证合并的哈希是否与 Merkle 树路径中的哈希匹配
    merkleVerify.hash <== combinedHash;
}

// 定义电路的输入输出
template Main() {
    signal input tradeHash;
    signal input buyerAddressHash;
    signal input buyerPhoneHash;
    signal input merkleRoot;
    signal input merklePath[10];
    signal input merkleIndex;

    component buyerInfoHashCircuit = BuyerInfoHashCircuit();
    buyerInfoHashCircuit.tradeHash <== tradeHash;
    buyerInfoHashCircuit.buyerAddressHash <== buyerAddressHash;
    buyerInfoHashCircuit.buyerPhoneHash <== buyerPhoneHash;
    buyerInfoHashCircuit.merkleRoot <== merkleRoot;
    buyerInfoHashCircuit.merklePath <== merklePath;
    buyerInfoHashCircuit.merkleIndex <== merkleIndex;
}
