## Mall合约

### 结构体

### 事件
- Payed:支付事件
```
event Payed(uint256 orderSn, address account, uint256 amount);
orderSn 订单号
account 账户
amount 支付数量
```

### 可读函数
- 订单号是否已经支付
```
function orderSns(uint256) returns (bool)
params uint256 订单号
return bool 是否已支付
```

### 写入函数
- 支付
```
function pay(
        uint256 orderSn,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    )
params orderSn 订单号
params value 支付金额
params deadline 截止时间
params v 签名数据
params r 签名数据
params s 签名数据
```
