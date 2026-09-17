---
layout: post
title: Neural Network from Scratch - Solving MNIST using RUST
date: 2024-11-11
tags: 
    - Programming
categories:
    - projects

permalink_name: projects
---

Despite my current hatred for many of the recent applications of neural networks, I do have some admiration for the way they work and how many problems have been solved by this invention.

As an exercise in both artifitial neural networks and rust programming, I decided to both implement a multi-perceptron neural network as well as a simple linear algebra for matrices in rust.

> If you want to know what "from scratch" costs you, ask the person who has to write their own matrix library.

## The theory (or: the part I stole from 3Blue1Brown)

A multi layer perceptron (hence forth refered to as MLP) is pretty much the simplest form of a feedforward neural network. It consists of an input layer, one or more hidden layers, and an output layer. Each layer is made up of perceptrons, which are akin to the neurons in the cerebral cortex. 

Sigmoid activation function and its' derivative:

$$\sigma(x) = \frac{1}{1+e^{-x}}$$

$$\sigma'(a)=a(a-1) \quad \text{where } a=\sigma(x)$$

#### Forward propagation

Input layer:

$$\mathbf{h} = \sigma\!\left(W_h\,\mathbf{x}\right)$$

Output layer:

$$\mathbf{o} = \sigma\!\left(W_o\,\mathbf{h}\right)$$

Prediction:

$$\hat{y}_i = \text{softmax}(\mathbf{o})_i = \frac{e^{o_i}}{\displaystyle\sum_j e^{o_j}}$$

#### Error signals

Output error

$$\boldsymbol{\delta}_o = \mathbf{y} - \mathbf{o}$$

Hidden error

$$\boldsymbol{\delta}_h = W_o^{\top}\,\boldsymbol{\delta}_o$$

MSE:

$$\mathcal{L} = \frac{1}{n_o}\sum_{i=1}^{n_o} \delta_{o,i}^{\,2}$$

#### Weight Updates

Output weights

$$W_o \leftarrow W_o + \eta\,\bigl(\boldsymbol{\delta}_o \odot \sigma'(\mathbf{o})\bigr)\,\mathbf{h}^{\top}$$

Hidden weights

$$W_h \leftarrow W_h + \eta\,\bigl(\boldsymbol{\delta}_h \odot \sigma'(\mathbf{h})\bigr)\,\mathbf{x}^{\top}$$


| Symbol                                | Key                             |
| ------------------------------------- | ------------------------------- |
| $\mathbf{x} \in \mathbb{R}^{784}$     | input (flattened 28×28 image)   |
| $W_h \in \mathbb{R}^{300 \times 784}$ | hidden weight matrix            |
| $W_o \in \mathbb{R}^{10 \times 300}$  | output weight matrix            |
| $\mathbf{h} \in \mathbb{R}^{300}$     | hidden activations              |
| $\mathbf{o} \in \mathbb{R}^{10}$      | output activations              |
| $\mathbf{y} \in \mathbb{R}^{10}$      | target label                    |
| $\odot$                               | element-wise (Hadamard) product |
| $\eta = 0.1$                          | learning rate                   |


None of this is novel, this is the same MLP everyone builds as a first exercise. The only midly interesting decision I made is that the target labels are not pure one-hot. I've clipped them to \[0.01, 0.99\] which should give the output neurons a slight starting gradient (?). I don't really know if this works or is even solving the problem I think it solves. I am far from a ML engineer.

## A matrix library,  badly

The first version of `Matrix` did what every maive implementation does, by allocating and returning a new Matrix on the heap for every operation. It's the cleanest possible API, and it makes some sense if you are trying to do this in rust and fighting the borrow checker :) Besides being the cleanest possible API, it is also catastrophically slow the moment you put in a training loop. I ended up rewritting it as I thought the reason my program was taking a really long time (spoiler: i was compiling with the dev profile in cargo)

A single epoch over MNIST is 60k examples, each doing a handful of matrix ops per forward/backward pass. Extrapolate that 20s/1k figure and you can see why I stopped waiting. The fix was to preallocate every buffer the network will every need once, up front.

```rust
pub fn dot_into(m1: &Matrix, m2: &Matrix, out: &mut Matrix) {
    assert!(m1.cols == m2.rows,  "Operand matrix dimensions are not compatible");
    assert!(m1.rows == out.rows && m2.cols == out.cols, "Result matrix dimensions are not compatible");

    for x in out.data.iter_mut() {
        *x = 0.0;
    }

    // loop order is i-k-j such that we get better use of cache locality
    // when accessing m2. I would the compiler sees this better than I do
    for i in 0..m1.rows {
        for k in 0..m1.cols {
            for j in 0..m2.cols {
                out.data[i * m2.cols + j] += m1.get(i, k) * m2.get(k, j);
            }
        }
    }
}
```

There is one place where the old, allocation-happy behaviour is still hiding thought: `transpose()` still returns a brand new heap-allocated matrix, and it get called 3 times inside the hot training loop. I could fix this, but to be honest I can't be bothered to keep hacking away at this _bespoke_ matrix/ml library. At least for now...

## Feeding MNIST to the network

MNIST ships as a pair of binary IDX files, one of each for the images and labels, and the format is super simple.

```
   magic number (0x0000)
   type of data 
   size in dimension 1
   size in dimension 2
   size in dimension 3
   ....
   size in dimension N
   raw data
```

Keep in mind that this is saved as big-endian (the wrong one)

```rust
let magic_number = u32::from_be_bytes(bytes[0..4].try_into().unwrap());
assert_eq!(magic_number, 0x00000803u32);

let num_images = u32::from_be_bytes(bytes[4..8].try_into().unwrap());
let rows = u32::from_be_bytes(bytes[8..12].try_into().unwrap());
let cols = u32::from_be_bytes(bytes[12..16].try_into().unwrap());
```

For this I thought of creating a macro for the `bytes[...].try_into().unwrap()`, but I've heard that hiding `unwrap()` inside a macro is a bad practice overall, so I've kept the pattern explicit. Each image is 28x28 = 784 bytes, which I normalize to \[0.0, 1.0\] and load directly as 784x1 column matrix. No explicit 2D representation is kept around for training, since the network only needs a flat input vector anyways.  

Labels are the more interesting bit. Instead of the usual one-hot encoding, I clip every target to \[0.01, 0.99\]:

```rust
let mut encoded = vec![0.01; 10];
encoded[target as usize] = 0.99;

labels.push(Matrix::new(10, 1, encoded));
```

which is the bit I mentioned earlier that I wasn't sure was pulling its weight, given the network is trained directly against raw sigmoid outputs (see below), and sigmoid never actually reaches 0 or 1.

## Wiring the network

The `NeuralNetwork` struct intentionally has single hiddne layer, and every intermediate matrix (hidden_out, output_out, the two error vectors, and four scratch buffers buf1..buf4) is allocated once in new() and reused for the entire training run:

```rust
pub struct NeuralNetwork {
    inputs: usize,
    hidden: usize,
    outputs: usize,
    hidden_weights : Matrix, // shape hidden x inputs
    output_weights : Matrix, // shape output x hidden

    hidden_out : Matrix, // shape hidden x 1
    output_out : Matrix, // shape output x 1
    hidden_error : Matrix, // shape hidden x 1
    output_error : Matrix,  // shape outputs x 1

    buf1 : Matrix,
    buf2 : Matrix,
    buf3 : Matrix,
    buf4 : Matrix
}
```

The forward pass and backpropagation steps are close to a literal transcription of the equations above:

```rust
// forward propagation
dot_into(&self.hidden_weights, &training_data[index], &mut self.hidden_out);
matrix_apply_inplace(&mut self.hidden_out, &NeuralNetwork::sigmoid);

dot_into(&self.output_weights, &self.hidden_out, &mut self.output_out);
matrix_apply_inplace(&mut self.output_out, &NeuralNetwork::sigmoid);

// find errors
subtract_into(&training_labels[index], &self.output_out, &mut self.output_error);
dot_into(&transpose(&self.output_weights), &self.output_error, &mut self.hidden_error);

// backpropagation - output weights
matrix_apply_inplace(&mut self.output_out, &NeuralNetwork::sigmoid_prime);
multiply_into(&self.output_error, &self.output_out, &mut self.buf1);

dot_into(&self.buf1, &transpose(&self.hidden_out), &mut self.buf2);
scale_assign(&mut self.buf2, learning_rate);
add_assign(&mut self.output_weights, &self.buf2);
```

One thing worth noting, because it took me a moment to notice while reading my own code back. **softmax is never applied during training 😭**. The `fit()` computes the error directly agains the raw sigmoid output, and softmax is only called inside `predict()`, purely to turn the ten output activations into something that looks like a probability distribution for the visualization I'll show. So the network is trained as ten independent sigmoid regressions against soft targets, and softmax is bolted on afterwards purely for display. It happes to still work reasonably well.

> Sigmoid outputs are already all positive and roughtly comparable in scale, so softmax on top doesn't do anything too weird

But it's not the true softmax-cross-entropy classifier setup you read about on any machine learning book. Consider this the first of probably several places where "_I built the thing that made intuitive sense to me_" and "_the mathematically principled thing_" diverge slightly. Taking inspiration from pretty much all technical books I've read, I'll leave this as an exercise to the reader :)

## Watching it learn

Once training and evaluating are done, `main.rs` open a raylib window and lets you step thorugh the 10000 test images. Each pixel is drawn as a white rectangle whose alpha channel is the modulated by the nomalized pixel value (fake grayscale):

```rust
d.draw_rectangle(
    col * BLOCK_SIZE,
    row * BLOCK_SIZE,
    BLOCK_SIZE,
    BLOCK_SIZE,
    Color::WHITE.alpha(
        m1.get_reshaped(row as usize, col as usize, 28, 28)
    )
);
```

![Raylib GUI for prediction visualization](/img/2024-11-11-Neural_Network_from_Scratch/nn_gui.png)

> Also, there is no bounds check on the index counter against `test_images.len()`. HOld down space for long enough, and the program will happily panic it self on an out-of-bounds array access. Consider it a feature that discourages the user from staring at the same 10k digit predictions for too long.

## Results

Before getting to the accuracy results, one number that surprised me enough was the runtime. I first ran a single epoch with a plain cargo run (by default, the debug build):

```bash 
$ time cargo run
# ...
# 977.19s user 17.98s system 87% cpu 19:02.42 total 

time $ cargo run --release
# ...
# 40.83s user 0.19s system 96% cpu 42.387s total
```

Nineteen minutes. For one epoch. Switching to the release build, we get a 27x speedup (real time) from a single compiler flag, and no algorithmic change whatsoever. 

And after that one epoch, evaluated over the full 10,000-image MNIST test set to an accuracy of 95.71%. Of course accuracy is not the only metric, but as I'm doing this from scratch, I really didn't think that it would be worth it to implement other more informative metrics. LeCun's original MNIST results show a 2 layer NN with 300 hidden units, using MSE and no preprocessing, just like ours, get a 95.3% accuracy result. 

There are many improvements to build upon this, such as using mini batching instead of pure online training, getting rid of the transpose reallocations in the hot path. But in the end this was a cool project and I would recommend it if you're trying to learn a new programming language as I was.

## References

- [But what is a neural network? — 3Blue1Brown](https://www.youtube.com/watch?v=aircAruvnKk)
- [IDX file format](https://www.fon.hum.uva.nl/praat/manual/IDX_file_format.html)
- [MNIST dataset format](https://github.com/cvdfoundation/mnist)
- [THE MNIST DATABASE of handwritten digits ](http://yann.lecun.com/exdb/mnist/) — Yann LeCun, Corinna Cortes, Christopher Burges. Source of the "2-layer NN, 300 hidden units, MSE" comparison above.

