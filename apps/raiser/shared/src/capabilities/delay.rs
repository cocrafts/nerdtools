use crux_core::{
	capability::{CapabilityContext, Operation},
	macros,
};
use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize, Clone, Debug, PartialEq, Eq)]
pub enum DelayOperation {
	GetRandom(usize, usize),
	Delay(usize),
}

#[derive(Serialize, Deserialize, Clone, Debug, PartialEq, Eq)]
pub enum DelayOutput {
	Random(usize),
	TimeUp,
}

impl Operation for DelayOperation {
	type Output = DelayOutput;
}

#[derive(macros::Capability)]
pub struct Delay<Ev> {
	context: CapabilityContext<DelayOperation, Ev>,
}

impl<Ev> Delay<Ev>
where
	Ev: 'static,
{
	pub fn new(context: CapabilityContext<DelayOperation, Ev>) -> Self {
		Self { context }
	}

	pub fn random<F>(&self, min: usize, max: usize, event: F)
	where
		F: Fn(usize) -> Ev + Send + 'static,
	{
		let ctx = self.context.clone();
		self.context.spawn(async move {
			let response = ctx
				.request_from_shell(DelayOperation::GetRandom(min, max))
				.await;

			let DelayOutput::Random(millis) = response else {
				panic!("Expected a random number")
			};
			ctx.request_from_shell(DelayOperation::Delay(millis)).await;

			ctx.update_app(event(millis));
		});
	}
}
